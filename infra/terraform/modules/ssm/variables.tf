variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "rds_address" {
  description = "Hostname do Amazon RDS (sem porta)"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL da fila SQS principal"
  type        = string
}

variable "elasticache_endpoint" {
  description = "Endpoint do cluster ElastiCache Redis"
  type        = string
}

variable "dynamodb_table" {
  description = "Nome da tabela DynamoDB de voluntários"
  type        = string
}

variable "dynamodb_ngo_index" {
  description = "Nome do GSI ngo_id no DynamoDB"
  type        = string
}
