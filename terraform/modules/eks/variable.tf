variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "eks_version" {
  description = "The version of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "The list of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "The list of CIDR blocks allowed for public access to the EKS cluster"
  type        = list(string)
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