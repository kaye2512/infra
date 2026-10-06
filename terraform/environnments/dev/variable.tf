variable "aws_region" {
    type       = string
    description = "The AWS region to deploy resources in."
    default    = "eu-west-3"
}

variable "aws_access_key" {
    type        = string
    description = "The AWS access key."
    sensitive   = true
}

variable "aws_secret_key" {
    type        = string
    description = "The AWS secret key."
    sensitive   = true
}