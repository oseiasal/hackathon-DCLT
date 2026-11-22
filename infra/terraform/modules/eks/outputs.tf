output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes"
  value       = aws_eks_cluster.this.endpoint
}

output "oidc_provider_arn" {
  description = "ARN do OIDC Provider do EKS"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "irsa_donation_role_arn" {
  description = "ARN da IAM Role IRSA do donation-service"
  value       = aws_iam_role.irsa_donation.arn
}

output "irsa_volunteer_role_arn" {
  description = "ARN da IAM Role IRSA do volunteer-service"
  value       = aws_iam_role.irsa_volunteer.arn
}

output "irsa_secrets_role_arn" {
  description = "ARN da IAM Role IRSA do external-secrets"
  value       = aws_iam_role.irsa_secrets.arn
}
