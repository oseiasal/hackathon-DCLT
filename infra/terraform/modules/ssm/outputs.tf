output "parameter_names" {
  description = "Mapa chave -> caminho completo no SSM Parameter Store"
  value       = { for k, v in aws_ssm_parameter.this : k => v.name }
}

output "parameter_arns" {
  description = "Mapa chave -> ARN no SSM Parameter Store"
  value       = { for k, v in aws_ssm_parameter.this : k => v.arn }
}
