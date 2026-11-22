include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//shared/ecr"
}

inputs = {
  repositories         = ["ngo-service", "donation-service", "volunteer-service"]
  image_tag_mutability = "IMMUTABLE"
  max_image_count      = 5
  force_delete         = true
}
