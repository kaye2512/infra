module "s3_bucket" {
  source = "../../modules/backend"
  bucket_name = var.bucket_name
}