# Dois bancos PostgreSQL separados (um por serviço), como exige o enunciado: nenhum serviço acessa o banco do outro.
locals {
  bancos = {
    os      = { nome = "oficina_os" }
    billing = { nome = "oficina_billing" }
  }
}

resource "random_password" "banco" {
  for_each = local.bancos
  length   = 24
  special  = false # evita caracteres que quebram a URL JDBC
}

resource "aws_security_group" "banco" {
  name        = "${var.projeto}-rds"
  description = "PostgreSQL acessivel somente pelos nos do EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL vindo dos nos do EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id, module.eks.cluster_primary_security_group_id]
  }
}

resource "aws_db_instance" "banco" {
  for_each = local.bancos

  identifier        = "${var.projeto}-${each.key}"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.classe_rds
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = each.value.nome
  username = "oficina"
  password = random_password.banco[each.key].result

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.banco.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  skip_final_snapshot     = true # ambiente de demonstração: destroy não deixa snapshot
  deletion_protection     = false
  apply_immediately       = true
}
