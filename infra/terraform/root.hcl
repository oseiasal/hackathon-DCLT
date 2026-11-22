locals {
  project_name = "solidarytech"
  aws_region   = get_env("AWS_REGION", "us-east-1")
  owner        = "platform-engineering"
  cost_center  = "hackathon-fase5"

  # Extrai o ambiente do caminho da pasta (ex: environments/dev -> "dev", shared/ecr -> "shared")
  path_parts  = split("/", path_relative_to_include())
  environment = local.path_parts[0] == "environments" ? local.path_parts[1] : "shared"

  state_bucket = get_env("TF_STATE_BUCKET", "${local.project_name}-tfstate-${get_aws_account_id()}-${local.aws_region}")
}

# Remote State S3 com lock nativo (Terraform >= 1.10 — sem tabela DynamoDB extra)
remote_state {
  backend = "s3"
  config = {
    bucket       = local.state_bucket
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Gera versions.tf padronizado para todas as stacks
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
  }
}
EOF
}

# Gera provider.tf com tags FinOps obrigatórias em todos os recursos AWS
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Project     = "${local.project_name}"
      Environment = "${local.environment}"
      ManagedBy   = "terragrunt"
      Owner       = "${local.owner}"
      CostCenter  = "${local.cost_center}"
    }
  }
}
EOF
}

inputs = {
  project_name = local.project_name
  environment  = local.environment
  aws_region   = local.aws_region
}
