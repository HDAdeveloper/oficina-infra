# Infraestrutura (Terraform) e ambiente local

- `terraform/`: VPC, EKS (2 x t3.medium), ECR, RDS PostgreSQL x2, DynamoDB x4, SNS/SQS/DLQ, roles IRSA, role OIDC da pipeline,
  Lambda de login por CPF e API Gateway.
- `local/`: configuracao do LocalStack (topicos, filas e tabelas) usada pelo `docker-compose.yml` do `oficina-workspace`.

## Como usar (AWS)

```powershell
$env:AWS_PROFILE = "oficina"
aws sts get-caller-identity          # confira a conta antes de qualquer coisa
cd terraform
copy terraform.tfvars.example terraform.tfvars   # ajuste os valores
terraform init
terraform plan
terraform apply
```

**Custo:** cerca de US$ 0,35 por hora enquanto estiver no ar. Ao terminar: `terraform destroy`, aguarde `Destroy complete!`
e confira com `terraform state list` (deve vir vazio). O estado e local e nao vai para o Git.
