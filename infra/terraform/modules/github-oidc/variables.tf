variable "project_name" {
  description = "Nome do projeto (usado na tag ABAC Project e nos prefixos de recursos)"
  type        = string
}

variable "role_name" {
  description = "Nome da IAM Role OIDC dedicada do GitHub Actions"
  type        = string
  default     = "solidarytech-github-actions-role"
}

variable "allowed_subjects" {
  description = "Lista de claims 'sub' do GitHub Actions autorizados na Trust Policy"
  type        = list(string)
}
