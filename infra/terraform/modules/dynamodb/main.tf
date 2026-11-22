resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "volunteer_id"

  attribute {
    name = "volunteer_id"
    type = "S"
  }

  attribute {
    name = "ngo_id"
    type = "N"
  }

  global_secondary_index {
    name            = var.ngo_index_name
    hash_key        = "ngo_id"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  tags = {
    Name    = "${var.project_name}-${var.environment}-${var.table_name}"
    Service = "volunteer-service"
  }
}
