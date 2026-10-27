#!/usr/bin/env bash
# Cria a mensageria da Saga no LocalStack. Idempotente: pode rodar várias vezes.
# Espelha o que o Terraform vai criar na AWS (Etapa 7).
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ACCOUNT="000000000000"   # conta fictícia do LocalStack
MAX_RECEIVE=3            # tentativas antes de ir para a DLQ

echo "[init] criando tópicos SNS"
CMD_TOPIC=$(awslocal sns create-topic --name oficina-saga-commands --query TopicArn --output text)
EVT_TOPIC=$(awslocal sns create-topic --name oficina-saga-events   --query TopicArn --output text)

# create_queue <nome>: cria a DLQ e a fila principal com redrive para a DLQ
create_queue() {
  local name="$1"
  awslocal sqs create-queue --queue-name "${name}-dlq" >/dev/null
  # RedrivePolicy é uma string JSON dentro do JSON de atributos (por isso as aspas escapadas)
  local dlq_arn="arn:aws:sqs:${REGION}:${ACCOUNT}:${name}-dlq"
  local attrs
  attrs=$(printf '{"VisibilityTimeout":"30","RedrivePolicy":"{\\"deadLetterTargetArn\\":\\"%s\\",\\"maxReceiveCount\\":\\"%s\\"}"}' \
          "$dlq_arn" "$MAX_RECEIVE")
  awslocal sqs create-queue --queue-name "$name" --attributes "$attrs" >/dev/null
  echo "[init] fila ${name} (+ DLQ ${name}-dlq)"
}

create_queue billing-commands
create_queue execution-commands
create_queue os-events

queue_arn() { echo "arn:aws:sqs:${REGION}:${ACCOUNT}:$1"; }

# subscribe <topic-arn> <fila> [filter-policy-json]
# RawMessageDelivery: o corpo da mensagem na fila é exatamente o envelope JSON publicado.
subscribe() {
  local topic="$1" queue="$2" filter="${3:-}"
  local sub
  sub=$(awslocal sns subscribe --topic-arn "$topic" --protocol sqs \
        --notification-endpoint "$(queue_arn "$queue")" \
        --attributes RawMessageDelivery=true \
        --query SubscriptionArn --output text)
  if [ -n "$filter" ]; then
    awslocal sns set-subscription-attributes --subscription-arn "$sub" \
      --attribute-name FilterPolicy --attribute-value "$filter"
  fi
  echo "[init] ${topic##*:} -> ${queue} ${filter:+(filtro $filter)}"
}

# Comandos: o orquestrador (OS Service) publica; cada serviço recebe só os seus (atributo "target")
subscribe "$CMD_TOPIC" billing-commands   '{"target":["billing"]}'
subscribe "$CMD_TOPIC" execution-commands '{"target":["execution"]}'
# Eventos: Billing e Execution publicam; o OS Service (orquestrador) recebe todos
subscribe "$EVT_TOPIC" os-events

touch /tmp/init-done   # sinaliza ao healthcheck do docker compose
echo "[init] mensageria pronta"
