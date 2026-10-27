variable "regiao" {
  description = "Região da AWS."
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Prefixo dos nomes dos recursos."
  type        = string
  default     = "oficina"
}

variable "versao_kubernetes" {
  description = "Versão do Kubernetes no EKS."
  type        = string
  default     = "1.33"
}

variable "tipo_no" {
  description = "Tipo de instância dos nós do EKS (t3.medium: 2 vCPU, 4 GiB)."
  type        = string
  default     = "t3.medium"
}

variable "quantidade_nos" {
  description = "Número de nós. 2 permite as 2 réplicas de cada serviço em nós diferentes."
  type        = number
  default     = 2
}

variable "classe_rds" {
  description = "Classe das instâncias RDS PostgreSQL."
  type        = string
  default     = "db.t4g.micro"
}

variable "github_organizacao" {
  description = "Usuário/organização dona dos repositórios no GitHub (confiança do OIDC para o deploy)."
  type        = string
  default     = "HDAdeveloper"
}

variable "os_service_url" {
  description = <<-EOT
    URL pública do OS Service (ex.: http://abc123.us-east-1.elb.amazonaws.com), conhecida só depois do primeiro
    deploy no Kubernetes. Vazia na 1ª aplicação; na 2ª, informe para criar as rotas do API Gateway e apontar a Lambda.
  EOT
  type        = string
  default     = ""
}

variable "jar_lambda" {
  description = "Caminho do JAR da Lambda (gerado por ./mvnw verify em auth-lambda)."
  type        = string
  default     = "../../auth-lambda/target/auth-lambda-1.0.0-SNAPSHOT.jar"
}
