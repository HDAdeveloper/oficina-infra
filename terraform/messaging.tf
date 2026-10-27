# Mensageria da Saga: espelha infra/local/localstack/init/01-messaging.sh (docs/eventos.md).
resource "aws_sns_topic" "comandos" {
  name = "${var.projeto}-saga-commands"
}

resource "aws_sns_topic" "eventos" {
  name = "${var.projeto}-saga-events"
}

locals {
  filas = ["billing-commands", "execution-commands", "os-events"]
}

# Dead-letter queues: depois de 3 tentativas a mensagem vai para lá, para análise manual
resource "aws_sqs_queue" "dlq" {
  for_each                  = toset(local.filas)
  name                      = "${each.key}-dlq"
  message_retention_seconds = 1209600 # 14 dias
}

resource "aws_sqs_queue" "fila" {
  for_each                   = toset(local.filas)
  name                       = each.key
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 3
  })
}

# O SNS precisa de permissão para escrever em cada fila
locals {
  origem_da_fila = {
    "billing-commands"   = aws_sns_topic.comandos.arn
    "execution-commands" = aws_sns_topic.comandos.arn
    "os-events"          = aws_sns_topic.eventos.arn
  }
}

resource "aws_sqs_queue_policy" "sns_para_fila" {
  for_each  = aws_sqs_queue.fila
  queue_url = each.value.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PermiteSNS"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = each.value.arn
      Condition = { ArnEquals = { "aws:SourceArn" = local.origem_da_fila[each.key] } }
    }]
  })
}

# Comandos: o OS Service publica; cada serviço recebe só os seus (atributo "target")
resource "aws_sns_topic_subscription" "comandos_billing" {
  topic_arn            = aws_sns_topic.comandos.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.fila["billing-commands"].arn
  raw_message_delivery = true
  filter_policy        = jsonencode({ target = ["billing"] })
}

resource "aws_sns_topic_subscription" "comandos_execution" {
  topic_arn            = aws_sns_topic.comandos.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.fila["execution-commands"].arn
  raw_message_delivery = true
  filter_policy        = jsonencode({ target = ["execution"] })
}

# Eventos: Billing e Execution publicam; o OS Service (orquestrador) recebe todos
resource "aws_sns_topic_subscription" "eventos_os" {
  topic_arn            = aws_sns_topic.eventos.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.fila["os-events"].arn
  raw_message_delivery = true
}
