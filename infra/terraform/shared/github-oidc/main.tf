module "github_oidc" {
  source = "../../modules/github-oidc"

  project_name     = var.project_name
  role_name        = var.role_name
  allowed_subjects = var.allowed_subjects
}
