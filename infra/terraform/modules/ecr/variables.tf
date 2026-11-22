variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente"
  type        = string
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "repositories" {
  description = "Lista de microsserviços para criar repositórios ECR"
  type        = list(string)
  default     = ["ngo-service", "donation-service", "volunteer-service"]
}

variable "image_tag_mutability" {
  description = "Mutabilidade das tags (IMMUTABLE garante 12-Factor #5)"
  type        = string
  default     = "IMMUTABLE"
}

variable "max_image_count" {
  description = "Quantidade máxima de imagens retidas por repositório (FinOps)"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Permite destruir o repositório mesmo com imagens (útil em ambiente de estudos)"
  type        = bool
  default     = true
}
