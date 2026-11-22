include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//environments/dev"
}

locals {
  alert_email  = get_env("FINOPS_ALERT_EMAIL", "")
  alert_emails = local.alert_email != "" ? [local.alert_email] : []
}

inputs = {
  eks_cluster_name         = "solidarytech-dev-eks"
  vpc_cidr                 = "10.0.0.0/16"
  az_count                 = 2
  single_nat_gateway       = true
  sqs_queue_name           = "solidary-donations"
  dynamodb_table_name      = "SolidaryTechVolunteers"
  dynamodb_ngo_index_name  = "ngo_id-index"
  dynamodb_enable_pitr     = true
  rds_instance_class       = "db.t3.micro"
  rds_multi_az             = false
  elasticache_node_type    = "cache.t3.micro"
  monthly_budget_limit_usd = 50
  alert_emails             = local.alert_emails
}
