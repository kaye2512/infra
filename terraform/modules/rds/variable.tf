variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs for the RDS instance."
}   

variable "environment" {
  type        = string
  description = "The environment name (e.g., dev, staging, prod)."
}

variable "allocated_storage" {
  type        = number
  description = "The allocated storage size in gigabytes for the RDS instance."
}

variable "db_name" {
  type        = string
  description = "The name of the database to create when the RDS instance is created."
}

variable "db_engine" {
  type        = string
  description = "The database engine to use for the RDS instance (e.g., mysql, postgres)."
}

variable "engine_version" {
  type        = string
  description = "The version of the database engine to use for the RDS instance."
}

variable "instance_class" {
  type        = string
  description = "The instance class to use for the RDS instance (e.g., db.t3.micro)."
}

variable "username" {
  type        = string
  description = "The username for the master user of the RDS instance."
}

variable "vpc_id" {
  type        = string
  description = "VPC dans lequel créer le security group de la base."
}

variable "allowed_security_groups" {
  type        = map(string)
  description = "Security groups autorisés à joindre PostgreSQL (clé fixe => ID)."
  default     = {}
}
