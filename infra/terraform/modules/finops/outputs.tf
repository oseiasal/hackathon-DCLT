output "budget_name" {
  description = "Nome do AWS Budget mensal"
  value       = aws_budgets_budget.monthly_cost.name
}

output "budget_arn" {
  description = "ARN do AWS Budget mensal"
  value       = aws_budgets_budget.monthly_cost.arn
}
