variable "ami_id" {
    type        = string
    description = "The AMI ID to use for the EC2 instance."
}

variable "instance_type" {
    type        = string
    description = "The instance type for the EC2 instance."
    default     = "t3.micro"
}

variable "security_group_id" {
    type        = string
    description = "The ID of the security group to associate with the EC2 instance."
}

variable "subnet_id" {
    type        = string
    description = "The ID of the subnet to launch the EC2 instance in."
}

variable "environment" {
    type        = string
    description = "The environment name (e.g., dev, staging, prod)."
}

variable "instance_name" {
    type        = string
    description = "The name to assign to the EC2 instance."
    default     = ""
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