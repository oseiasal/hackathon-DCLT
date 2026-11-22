module "network" {
  source = "../../modules/network"

  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  eks_cluster_name   = var.eks_cluster_name
}

module "finops" {
  source = "../../modules/finops"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region
  monthly_budget_limit_usd = var.monthly_budget_limit_usd
  alert_emails             = var.alert_emails
}
