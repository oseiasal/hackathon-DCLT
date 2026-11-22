output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  value = module.network.private_data_subnet_ids
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "sqs_dlq_url" {
  value = module.sqs.dlq_url
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_secret_arn" {
  value = module.rds.master_user_secret_arn
}

output "elasticache_endpoint" {
  value = module.elasticache.endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "irsa_donation_role_arn" {
  value = module.eks.irsa_donation_role_arn
}

output "irsa_volunteer_role_arn" {
  value = module.eks.irsa_volunteer_role_arn
}

output "irsa_secrets_role_arn" {
  value = module.eks.irsa_secrets_role_arn
}

output "ssm_parameter_names" {
  value = module.ssm.parameter_names
}

output "budget_name" {
  value = module.finops.budget_name
}
