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

variable "vpc_cidr" {
    type        = string
    description = "The CIDR block for the VPC."
}

variable "public_subnet_cidr" {
    type        = string
    description = "The CIDR block for the public subnet."
}

variable "private_subnet_cidr" {
    type        = string
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
}