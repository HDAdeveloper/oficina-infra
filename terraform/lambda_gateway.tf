# JWT_SECRET único, igual em todos os serviços e na Lambda (HS256 compartilhado, ADR-007)
resource "random_password" "jwt" {
  length  = 48
  special = false
}

# ---------------------------------------------------------------------------------------------------------
# Lambda de autenticação por CPF
# ---------------------------------------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${var.projeto}-auth-cpf-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.projeto}-auth-cpf"
  retention_in_days = 14
}

resource "aws_lambda_function" "auth" {
  function_name = "${var.projeto}-auth-cpf"
  role          = aws_iam_role.lambda.arn
  runtime       = "java21"
  handler       = "br.com.oficina.auth.AuthHandler::handleRequest"
  memory_size   = 512
  timeout       = 15

  filename         = var.jar_lambda
  source_code_hash = filebase64sha256(var.jar_lambda)

  environment {
    variables = {
      JWT_SECRET     = random_password.jwt.result
      OS_SERVICE_URL = var.os_service_url != "" ? var.os_service_url : "http://os-service-ainda-nao-publicado"
      TOKEN_MINUTOS  = "60"
    }
  }

  # A pipeline da Lambda publica o código novo (aws lambda update-function-code): o Terraform não desfaz isso
  lifecycle {
    ignore_changes = [source_code_hash]
  }

  depends_on = [aws_cloudwatch_log_group.lambda, aws_iam_role_policy_attachment.lambda_logs]
}

# ---------------------------------------------------------------------------------------------------------
# API Gateway (HTTP API): ponto de entrada público.
#   POST /auth/cpf  -> Lambda
#   /api/*, Swagger e saúde -> OS Service (só depois que a URL dele é informada, 2ª aplicação)
# Billing e Execution não são expostos: só conversam pela mensageria.
# ---------------------------------------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "entrada" {
  name          = "${var.projeto}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "padrao" {
  api_id      = aws_apigatewayv2_api.entrada.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.entrada.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth.invoke_arn
  payload_format_version = "1.0" # o handler usa APIGatewayProxyRequestEvent (formato 1.0)
}

resource "aws_apigatewayv2_route" "auth_cpf" {
  api_id    = aws_apigatewayv2_api.entrada.id
  route_key = "POST /auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.entrada.execution_arn}/*/*"
}

locals {
  rotas_os_todas = {
    "ANY /api/{proxy+}"         = "/api/{proxy}"
    "GET /actuator/health"      = "/actuator/health"
    "GET /v3/api-docs"          = "/v3/api-docs"
    "GET /v3/api-docs/{proxy+}" = "/v3/api-docs/{proxy}"
    "GET /swagger-ui.html"      = "/swagger-ui.html"
    "GET /swagger-ui/{proxy+}"  = "/swagger-ui/{proxy}"
  }

  # Só existem depois que a URL do OS Service é informada (2ª aplicação)
  rotas_os = { for rota, caminho in local.rotas_os_todas : rota => caminho if var.os_service_url != "" }
}

resource "aws_apigatewayv2_integration" "os" {
  for_each = local.rotas_os

  api_id             = aws_apigatewayv2_api.entrada.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = "${var.os_service_url}${each.value}"
}

resource "aws_apigatewayv2_route" "os" {
  for_each = local.rotas_os

  api_id    = aws_apigatewayv2_api.entrada.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.os[each.key].id}"
}
