data "aws_availability_zones" "disponiveis" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.disponiveis.names, 0, 2)
}

# Os nós do EKS ficam nas sub-redes públicas (sem NAT Gateway, que custa ~US$ 33/mês por zona); só entram
# pelas portas que os Security Groups liberam. Os bancos ficam nas sub-redes privadas, sem rota para a internet.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.16"

  name = "${var.projeto}-vpc"
  cidr = "10.20.0.0/16"
  azs  = local.azs

  public_subnets   = ["10.20.0.0/24", "10.20.1.0/24"]
  database_subnets = ["10.20.10.0/24", "10.20.11.0/24"]

  enable_nat_gateway                 = false
  create_database_subnet_group       = true
  create_database_subnet_route_table = true # tabela de rotas própria, sem saída para a internet
  map_public_ip_on_launch            = true
  enable_dns_hostnames               = true
  enable_dns_support                 = true

  # Permite ao Kubernetes criar o balanceador público do OS Service nestas sub-redes
  public_subnet_tags = {
    "kubernetes.io/role/elb"                   = "1"
    "kubernetes.io/cluster/${var.projeto}-eks" = "shared"
  }
}
