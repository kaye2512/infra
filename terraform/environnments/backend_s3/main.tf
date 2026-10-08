data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.bucket_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

module "s3_bucket" {
  source      = "../../modules/backend"
  bucket_name = local.bucket_name
}
