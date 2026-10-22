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

variable "node_instance_type" {
  description = "The instance type for the EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "capacity_type" {
  description = "The capacity type for the EKS worker nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "ami_type" {
  description = "The AMI type for the EKS worker nodes (AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, etc.)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Valid values are 'MUTABLE' or 'IMMUTABLE'."
  type        = string
  default     = "IMMUTABLE"
}

variable "force_delete" {
  description = "Whether to force delete the repository."
  type        = bool
  default     = true
}

variable "scan_on_push" {
  description = "Whether to scan images on push."
  type        = bool
  default     = true
}

variable "lifecycle_policy_max_image_count" {
  description = "The maximum number of images to retain in the ECR repository."
  type        = number
  default     = 10
}

variable "instance_class" {
  description = "The instance class for the RDS database."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "The allocated storage size in gigabytes for the RDS database."
  type        = number
  default     = 20
}

variable "db_engine" {
  description = "The database engine for the RDS instance (e.g., mysql, postgres)."
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "The version of the database engine for the RDS instance."
  type        = string
  default     = "15"
}

variable "db_name" {
  description = "The name of the database to create when the RDS instance is created."
  type        = string
  default     = "mydatabase"
}