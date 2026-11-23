variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "role_name" {
  type    = string
  default = "solidarytech-github-actions-role"
}

variable "allowed_subjects" {
  type = list(string)
}
