variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente"
  type        = string
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "monthly_budget_limit_usd" {
  description = "Teto mensal de gastos em USD para alertas FinOps"
  type        = number
  default     = 50
}

variable "alert_emails" {
  description = "Lista de e-mails para receber alertas de 80% atual e 100% previsto"
  type        = list(string)
  default     = []
}
