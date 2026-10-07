variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
  default     = "eu-west-3"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform backend."
}
