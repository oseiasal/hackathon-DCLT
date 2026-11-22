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

module "sqs" {
  source = "../../modules/sqs"

  project_name = var.project_name
  environment  = var.environment
  queue_name   = var.sqs_queue_name
}

module "dynamodb" {
  source = "../../modules/dynamodb"

  project_name   = var.project_name
  environment    = var.environment
  table_name     = var.dynamodb_table_name
  ngo_index_name = var.dynamodb_ngo_index_name
  enable_pitr    = var.dynamodb_enable_pitr
}

module "rds" {
  source = "../../modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.network.private_data_subnet_ids
  security_group_id = module.network.sg_rds_id
  instance_class    = var.rds_instance_class
  multi_az          = var.rds_multi_az
}

module "elasticache" {
  source = "../../modules/elasticache"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.network.private_data_subnet_ids
  security_group_id = module.network.sg_elasticache_id
  node_type         = var.elasticache_node_type
}

module "finops" {
  source = "../../modules/finops"

  project_name             = var.project_name
  environment              = var.environment
  aws_region               = var.aws_region
  monthly_budget_limit_usd = var.monthly_budget_limit_usd
  alert_emails             = var.alert_emails
}
