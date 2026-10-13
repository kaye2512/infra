resource "aws_ecr_repository" "main" {
  name                 = "${var.environment}-ecr-repo"
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}


