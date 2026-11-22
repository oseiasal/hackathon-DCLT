output "repository_urls" {
  description = "Mapa nome do serviço -> URL do repositório ECR"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "Mapa nome do serviço -> ARN do repositório ECR"
  value       = { for k, v in aws_ecr_repository.this : k => v.arn }
}
