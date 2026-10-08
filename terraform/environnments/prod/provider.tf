terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67.0"
    }
  }

  backend "s3" {
    bucket       = "my-terraform-state-bucket-225989374284-eu-west-3"
    key          = "prod/terraform.tfstate"
    region       = "eu-west-3"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

