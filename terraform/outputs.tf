output "regiao" {
  value = var.regiao
}

output "cluster_eks" {
  description = "Nome do cluster (aws eks update-kubeconfig --name ...)."
  value       = module.eks.cluster_name
}

output "repositorios_ecr" {
  value = { for k, r in aws_ecr_repository.servico : k => r.repository_url }
}

output "endpoint_banco_os" {
  value = aws_db_instance.banco["os"].address
}

output "endpoint_banco_billing" {
  value = aws_db_instance.banco["billing"].address
}

output "senha_banco_os" {
  value     = random_password.banco["os"].result
  sensitive = true
}

output "senha_banco_billing" {
  value     = random_password.banco["billing"].result
  sensitive = true
}

output "jwt_secret" {
  value     = random_password.jwt.result
  sensitive = true
}

output "topico_comandos_arn" {
  value = aws_sns_topic.comandos.arn
}

output "topico_eventos_arn" {
  value = aws_sns_topic.eventos.arn
}

output "roles_dos_servicos" {
  description = "Roles IRSA, usadas na anotação eks.amazonaws.com/role-arn de cada ServiceAccount."
  value       = { for k, r in aws_iam_role.servico : k => r.arn }
}

output "role_da_pipeline" {
  description = "Vira o segredo AWS_ROLE_ARN dos repositórios no GitHub."
  value       = aws_iam_role.pipeline.arn
}

output "nome_da_lambda" {
  value = aws_lambda_function.auth.function_name
}

output "url_da_api" {
  description = "Endereço público (API Gateway)."
  value       = aws_apigatewayv2_api.entrada.api_endpoint
}
