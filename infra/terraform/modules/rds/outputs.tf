output "endpoint" {
  description = "Endpoint completo (host:porta) do RDS"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Hostname do RDS"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Porta do RDS"
  value       = aws_db_instance.this.port
}

output "master_user_secret_arn" {
  description = "ARN do segredo gerenciado automaticamente no AWS Secrets Manager"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
