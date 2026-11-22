variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "repositories" {
  type    = list(string)
  default = ["ngo-service", "donation-service", "volunteer-service"]
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
}

variable "max_image_count" {
  type    = number
  default = 10
}

variable "force_delete" {
  type    = bool
  default = true
}
