locals {
  servicos = ["os-service", "billing-service", "execution-service"]
}

resource "aws_ecr_repository" "servico" {
  for_each             = toset(local.servicos)
  name                 = "${var.projeto}/${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # permite o terraform destroy mesmo com imagens

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "servico" {
  for_each   = aws_ecr_repository.servico
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantém só as 10 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
