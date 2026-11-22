include "root" {
  path = find_in_parent_folders("root.hcl")
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
  monthly_budget_limit_usd = 50
  alert_emails             = local.alert_emails
}
