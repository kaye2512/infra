variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Valid values are 'MUTABLE' or 'IMMUTABLE'."
  type        = string
}

variable "force_delete" {
  description = "Whether to force delete the repository."
  type        = bool
}

variable "scan_on_push" {
  description = "Whether to scan images on push."
  type        = bool
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
}

variable "lifecycle_policy_max_image_count" {
  description = "The maximum number of images to retain in the ECR repository."
  type        = number
}