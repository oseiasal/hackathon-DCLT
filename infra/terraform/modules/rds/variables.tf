variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets privadas de dados para o RDS"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security Group do RDS (porta 5432)"
  type        = string
}

variable "engine_version" {
  description = "Versão do PostgreSQL"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Classe da instância RDS (FinOps: db.t3.micro em dev)"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial em GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Limite máximo de autoscaling de disco em GB"
  type        = number
  default     = 50
}

variable "db_name" {
  description = "Nome do banco inicial criado no RDS"
  type        = string
  default     = "ngo_db"
}

variable "db_username" {
  description = "Usuário master do PostgreSQL"
  type        = string
  default     = "solidary"
}

variable "multi_az" {
  description = "Multi-AZ (false em dev para FinOps, true em prod para HA)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Dias de retenção de backup automático"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Pular snapshot final ao destruir (true em dev)"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Proteção contra deleção acidental (true em prod)"
  type        = bool
  default     = false
}
