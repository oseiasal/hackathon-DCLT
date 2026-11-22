locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_budgets_budget" "monthly_cost" {
  name         = "${local.name_prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$${var.project_name}"]
  }

  dynamic "notification" {
    for_each = length(var.alert_emails) > 0 ? [
      {
        threshold         = 80
        notification_type = "ACTUAL"
      },
      {
        threshold         = 100
        notification_type = "FORECASTED"
      }
    ] : []

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.notification_type
      subscriber_email_addresses = var.alert_emails
    }
  }
}
