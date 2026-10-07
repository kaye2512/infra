terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67.0"
    }
  }

  backend "s3" {
    bucket = "my-terraform-state-bucket"
    key    = "terraform.tfstate"
    region = "eu-west-3"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region
}

