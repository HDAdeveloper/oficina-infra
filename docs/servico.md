# Infraestrutura — documentação

## Responsabilidade

Tudo o que o sistema precisa na AWS, como código (Terraform), mais a configuração do ambiente local. Os serviços não criam infraestrutura: só a consomem.

## O que o Terraform cria (`terraform/`)

| Arquivo | Recursos |
|---|---|
| `network.tf` | VPC com sub-redes públicas (nós do EKS) e de banco (isoladas), sem NAT Gateway para reduzir custo |
| `eks.tf` | Cluster EKS 1.33 e grupo de nós (2 × t3.medium) |
| `ecr.tf` | Três repositórios de imagens (os, billing, execution) com política de retenção |
| `rds.tf` | Dois PostgreSQL 16 (`db.t4g.micro`): `oficina_os` e `oficina_billing`, com senha gerada |
| `dynamodb.tf` | Quatro tabelas do Execution Service (prefixo `execution_`) |
| `messaging.tf` | Tópicos SNS `oficina-saga-commands` / `oficina-saga-events`, filas SQS e DLQs (3 tentativas) |
| `iam.tf` | Roles por serviço (IRSA, mínimo privilégio) e role da pipeline via OIDC do GitHub (só a branch `main`) |
| `lambda_gateway.tf` | Lambda `oficina-auth-cpf` e API Gateway HTTP |
| `outputs.tf` | Endpoints, ARNs e segredos que o script de deploy usa |

Entrada do API Gateway: `POST /auth/cpf` vai para a Lambda; as rotas do OS Service só são criadas quando `os_service_url` é informado (**apply em duas fases**).

## Ambiente local (`local/`)

`local/localstack/init/` cria no LocalStack os mesmos tópicos, filas e tabelas. É usado pelo `docker-compose.yml` do repositório `oficina-workspace`.

## Como usar

```powershell
$env:AWS_PROFILE = "oficina"
aws sts get-caller-identity          # confira a conta antes de qualquer coisa
cd terraform
copy terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply                      # 1ª fase, sem os_service_url
# depois do deploy dos serviços: terraform apply -var os_service_url=http://<endereço do balanceador>
```

## Custos e cuidados

- Cerca de **US$ 0,35 por hora** enquanto estiver no ar (EKS, nós, dois RDS). Suba perto do uso e destrua em seguida: `terraform destroy`.
- Confira com `terraform state list` (deve vir vazio) e no console (EKS, RDS, Load Balancers, EC2).
- O estado é local e **não vai para o Git**; `terraform.tfvars` também fica de fora.
- Segredos (senhas, `JWT_SECRET`) são gerados pelo Terraform e entregues ao cluster pelo script de deploy; nunca ficam em arquivo versionado.

## Deploy dos serviços

O script `scripts/deploy/deploy-aws.ps1` (no `oficina-workspace`) lê os outputs, envia as imagens ao ECR e aplica os manifestos Kubernetes. Depois, a pipeline de cada serviço só publica novas versões.

## Documentação compartilhada do projeto

| Documento | Conteúdo |
|---|---|
| [`arquitetura.md`](arquitetura.md) | Visão geral, hexagonal, dados, Saga, mensageria, segurança, CI/CD |
| [`ddd.md`](ddd.md) | Contextos, agregados, estados e linguagem ubíqua |
| [`eventos.md`](eventos.md) | Comandos, eventos, envelope, fluxo feliz e compensações da Saga |
| [`adr/`](adr/) | Decisões de arquitetura e justificativas |
