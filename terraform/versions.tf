terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Estado local (arquivo terraform.tfstate, fora do Git). Suficiente para um ambiente de demonstração
  # criado e destruído por uma pessoa; para trabalho em equipe, trocar por backend "s3" com lock.
}

provider "aws" {
  region = var.regiao

  default_tags {
    tags = {
      Projeto = var.projeto
      Origem  = "terraform"
    }
  }
}
