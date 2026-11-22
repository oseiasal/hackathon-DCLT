variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "eks_cluster_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "sqs_queue_name" {
  type    = string
  default = "solidary-donations"
}

variable "dynamodb_table_name" {
  type    = string
  default = "SolidaryTechVolunteers"
}

variable "dynamodb_ngo_index_name" {
  type    = string
  default = "ngo_id-index"
}

variable "dynamodb_enable_pitr" {
  type    = bool
  default = true
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "elasticache_node_type" {
  type    = string
  default = "cache.t3.micro"
}

variable "monthly_budget_limit_usd" {
  type    = number
  default = 50
}

variable "alert_emails" {
  type    = list(string)
  default = []
}
