variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
}

variable "public_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the public subnet."
}

variable "private_subnet_cidr" {
  type        = list(string)
  description = "The CIDR block for the private subnet."
}

variable "ami_id" {
  type        = string
  description = "The AMI ID to use for the EC2 instance."
}

variable "instance_type" {
  type        = string
  description = "The instance type for the EC2 instance."
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  type        = string
  description = "The CIDR block allowed for SSH access."
}

variable "environment" {
  type        = string
  description = "The environment name (e.g., dev, staging, prod)."
}

variable "hostname" {
  type        = string
  description = "The hostname to assign to the EC2 instance."
}

variable "username" {
  type        = string
  description = "The username to create on the EC2 instance."
}

variable "ssh_public_key" {
  type        = string
  description = "The SSH public key to add to the EC2 instance for the specified user."
  sensitive   = true
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "eks_version" {
  description = "The version of the EKS cluster"
  type        = string
}

variable "endpoint_private_access" {
  description = "Whether the EKS cluster endpoint is accessible privately"
  type        = bool
  default     = false
}

variable "endpoint_public_access" {
  description = "Whether the EKS cluster endpoint is accessible publicly"
  type        = bool
  default     = false
}