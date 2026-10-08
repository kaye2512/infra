output "s3_bucket_name" {
  description = "Name of the S3 bucket to use in the backend blocks of the other environments."
  value       = module.s3_bucket.s3_bucket_name
}
