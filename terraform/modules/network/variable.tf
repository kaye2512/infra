variable "vpc_cidr_block" {
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

variable "availability_zones" {
  type        = list(string)
  description = "The availability zones for the subnets."
}