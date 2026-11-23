output "role_arn" {
  description = "ARN da IAM Role OIDC dedicada para configurar no secret AWS_ROLE_TO_ASSUME do GitHub"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Nome da IAM Role OIDC"
  value       = aws_iam_role.github_actions.name
}
