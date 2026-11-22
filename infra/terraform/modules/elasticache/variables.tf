variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas de dados para o ElastiCache"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group do ElastiCache (porta 6379)"
  type        = string
}

variable "engine_version" {
  description = "Versão do Redis"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "Tipo do nó Redis (FinOps: cache.t3.micro em dev)"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_nodes" {
  description = "Número de nós do cluster Redis"
  type        = number
  default     = 1
}

variable "parameter_group_name" {
  description = "Parameter group do Redis"
  type        = string
  default     = "default.redis7"
}
