locals {
  prefix = "/${var.project_name}/${var.environment}"

  parameters = {
    rds_address          = var.rds_address
    sqs_queue_url        = var.sqs_queue_url
    elasticache_endpoint = var.elasticache_endpoint
    dynamodb_table       = var.dynamodb_table
    dynamodb_ngo_index   = var.dynamodb_ngo_index
  }
}

resource "aws_ssm_parameter" "this" {
  for_each = local.parameters

  name        = "${local.prefix}/${each.key}"
  description = "Parametro de runtime ${each.key} (${var.project_name}-${var.environment})"
  type        = "String"
  tier        = "Standard"
  value       = each.value
  overwrite   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-ssm-${each.key}"
  }
}
