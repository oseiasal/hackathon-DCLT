variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Quantidade de Availability Zones (2 em dev, 3 em prod)"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Usa 1 único NAT Gateway para economia FinOps em dev (false em prod para HA)"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "Nome do cluster EKS para tags de discovery das subnets"
  type        = string
}
