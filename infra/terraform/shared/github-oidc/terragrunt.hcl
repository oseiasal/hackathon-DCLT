include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//shared/github-oidc"
}

inputs = {
  role_name = "solidarytech-github-actions-role"
  # Trancado exclusivamente no repositório oseiasal/hackathon-DCLT (formato novo com IDs imutáveis + clássico)
  allowed_subjects = [
    "repo:oseiasal@39315752/hackathon-DCLT@1466449539:*",
    "repo:oseiasal/hackathon-DCLT:*"
  ]
}
