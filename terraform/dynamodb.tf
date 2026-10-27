# Tabelas do Execution Service (mesmo desenho de CriadorDeTabelas.java, que só é usado no ambiente local).
locals {
  prefixo_dynamo = "execution_"
}

resource "aws_dynamodb_table" "estoque" {
  name         = "${local.prefixo_dynamo}estoque"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "codigo"

  attribute {
    name = "codigo"
    type = "S"
  }
}

resource "aws_dynamodb_table" "execucao" {
  name         = "${local.prefixo_dynamo}execucao"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "osId"

  attribute {
    name = "osId"
    type = "N"
  }
  attribute {
    name = "status"
    type = "S"
  }
  attribute {
    name = "criadoEm"
    type = "S"
  }

  global_secondary_index {
    name            = "status-criadoEm-index"
    hash_key        = "status"
    range_key       = "criadoEm"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "mensagem_processada" {
  name         = "${local.prefixo_dynamo}mensagem_processada"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "messageId"

  attribute {
    name = "messageId"
    type = "S"
  }

  ttl {
    attribute_name = "expiraEm"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "outbox" {
  name         = "${local.prefixo_dynamo}outbox"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "messageId"

  attribute {
    name = "messageId"
    type = "S"
  }
  attribute {
    name = "pendente"
    type = "S"
  }
  attribute {
    name = "ordem"
    type = "S"
  }

  global_secondary_index {
    name            = "pendentes-index"
    hash_key        = "pendente"
    range_key       = "ordem"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expiraEm"
    enabled        = true
  }
}
