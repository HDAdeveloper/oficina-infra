locals {
  namespace_k8s = "oficina"
}

# ---------------------------------------------------------------------------------------------------------
# IRSA: cada serviço assume uma role própria, só com o que precisa (sem chaves de acesso nos pods).
# ---------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "confianca_irsa" {
  for_each = toset(local.servicos)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:${local.namespace_k8s}:${each.key}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "servico" {
  for_each           = toset(local.servicos)
  name               = "${var.projeto}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.confianca_irsa[each.key].json
}

locals {
  permissoes_servico = {
    "os-service" = {
      publica = [aws_sns_topic.comandos.arn]
      consome = [aws_sqs_queue.fila["os-events"].arn]
    }
    "billing-service" = {
      publica = [aws_sns_topic.eventos.arn]
      consome = [aws_sqs_queue.fila["billing-commands"].arn]
    }
    "execution-service" = {
      publica = [aws_sns_topic.eventos.arn]
      consome = [aws_sqs_queue.fila["execution-commands"].arn]
    }
  }

  tabelas_dynamo = [
    aws_dynamodb_table.estoque.arn,
    aws_dynamodb_table.execucao.arn,
    aws_dynamodb_table.mensagem_processada.arn,
    aws_dynamodb_table.outbox.arn,
  ]
}

data "aws_iam_policy_document" "servico" {
  for_each = local.permissoes_servico

  statement {
    sid       = "PublicaNoSNS"
    actions   = ["sns:Publish"]
    resources = each.value.publica
  }

  statement {
    sid       = "ConsomeDaFila"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
    resources = each.value.consome
  }
}

resource "aws_iam_role_policy" "servico" {
  for_each = local.permissoes_servico
  name     = "mensageria"
  role     = aws_iam_role.servico[each.key].id
  policy   = data.aws_iam_policy_document.servico[each.key].json
}

# Só o Execution usa o DynamoDB
data "aws_iam_policy_document" "dynamo_execution" {
  statement {
    sid = "TabelasDoExecution"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:ConditionCheckItem",
      "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem", "dynamodb:DescribeTable",
    ]
    resources = concat(local.tabelas_dynamo, [for arn in local.tabelas_dynamo : "${arn}/index/*"])
  }
}

resource "aws_iam_role_policy" "dynamo_execution" {
  name   = "dynamodb"
  role   = aws_iam_role.servico["execution-service"].id
  policy = data.aws_iam_policy_document.dynamo_execution.json
}

# ---------------------------------------------------------------------------------------------------------
# Pipeline do GitHub Actions (OIDC, sem chaves de longa duração): publica imagens, aplica os manifestos no
# EKS e atualiza o código da Lambda.
# ---------------------------------------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "confianca_github" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_organizacao}/*:ref:refs/heads/main"] # só a branch main faz deploy
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name               = "${var.projeto}-pipeline"
  assume_role_policy = data.aws_iam_policy_document.confianca_github.json
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    sid       = "LoginNoECR"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "PublicaImagens"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
    ]
    resources = [for r in aws_ecr_repository.servico : r.arn]
  }
  statement {
    sid       = "DescobreOCluster"
    actions   = ["eks:DescribeCluster"]
    resources = [module.eks.cluster_arn]
  }
  statement {
    sid       = "AtualizaALambda"
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction"]
    resources = [aws_lambda_function.auth.arn]
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "deploy"
  role   = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.pipeline.json
}
