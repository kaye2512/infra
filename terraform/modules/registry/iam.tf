data "aws_ecr_lifecycle_policy_document" "ecr_lifecycle_policy_document" {
  rule {
    priority    = 1
    description = "Keep only the ${var.lifecycle_policy_max_image_count} most recent images"

    selection {
      tag_status   = "any"
      count_type   = "imageCountMoreThan"
      count_number = var.lifecycle_policy_max_image_count
    }
  }
}

resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = data.aws_ecr_lifecycle_policy_document.ecr_lifecycle_policy_document.json
}
