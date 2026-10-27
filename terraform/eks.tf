module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "${var.projeto}-eks"
  cluster_version = var.versao_kubernetes

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true # quem aplica o Terraform administra o cluster
  enable_irsa                              = true # cada serviço assume uma role IAM própria (iam.tf)

  # O papel que a pipeline do GitHub assume (iam.tf) também administra o cluster para aplicar os manifestos
  access_entries = {
    pipeline = {
      principal_arn = aws_iam_role.pipeline.arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  eks_managed_node_groups = {
    principal = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.tipo_no]
      min_size       = var.quantidade_nos
      max_size       = var.quantidade_nos + 1
      desired_size   = var.quantidade_nos
      subnet_ids     = module.vpc.public_subnets
    }
  }
}
