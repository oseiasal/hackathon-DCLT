module "ecr" {
  source = "../../modules/ecr"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  repositories         = var.repositories
  image_tag_mutability = var.image_tag_mutability
  max_image_count      = var.max_image_count
  force_delete         = var.force_delete
}
