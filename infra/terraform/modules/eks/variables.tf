variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Nome do cluster Amazon EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versão do Kubernetes no EKS"
  type        = string
  default     = "1.31"
}

variable "private_app_subnet_ids" {
  description = "Subnets privadas de aplicação onde o EKS e os nodes rodam"
  type        = list(string)
}

variable "sg_rds_id" {
  description = "Security Group do RDS para liberar acesso dos nodes EKS"
  type        = string
}

variable "sg_elasticache_id" {
  description = "Security Group do ElastiCache para liberar acesso dos nodes EKS"
  type        = string
}

variable "node_instance_types" {
  description = "Tipos de instância EC2 do Managed Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "capacity_type" {
  description = "ON_DEMAND ou SPOT (FinOps)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_desired_size" {
  description = "Quantidade desejada de worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade mínima de worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Quantidade máxima de worker nodes"
  type        = number
  default     = 4
}

variable "k8s_namespace" {
  description = "Namespace Kubernetes dos microsserviços (para trust policy IRSA)"
  type        = string
  default     = "solidarytech"
}

variable "sqs_queue_arn" {
  description = "ARN da fila SQS para IRSA do donation-service"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN da tabela DynamoDB para IRSA do volunteer-service"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN do segredo do RDS no Secrets Manager para IRSA do External Secrets"
  type        = string
}

variable "admin_principal_arns" {
  description = "ARNs IAM adicionais com acesso admin no cluster via EKS Access Entries"
  type        = list(string)
  default     = []
}
