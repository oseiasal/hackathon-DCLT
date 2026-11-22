variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "table_name" {
  description = "Nome da tabela DynamoDB de voluntários"
  type        = string
  default     = "SolidaryTechVolunteers"
}

variable "ngo_index_name" {
  description = "Nome do Global Secondary Index por ngo_id"
  type        = string
  default     = "ngo_id-index"
}

variable "enable_pitr" {
  description = "Habilita Point-in-Time Recovery (backup contínuo)"
  type        = bool
  default     = true
}
