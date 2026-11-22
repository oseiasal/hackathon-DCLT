output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR da VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs das subnets privadas de aplicação (EKS)"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs das subnets privadas de dados (RDS / ElastiCache)"
  value       = aws_subnet.private_data[*].id
}

output "sg_eks_nodes_id" {
  description = "Security Group dos worker nodes EKS"
  value       = aws_security_group.eks_nodes.id
}

output "sg_rds_id" {
  description = "Security Group do Amazon RDS"
  value       = aws_security_group.rds.id
}

output "sg_elasticache_id" {
  description = "Security Group do Amazon ElastiCache"
  value       = aws_security_group.elasticache.id
}
