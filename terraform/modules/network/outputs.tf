output "main_vpc" {
  description = "The ID of the VPC."
  value       = aws_vpc.main_vpc.id
}

output "public_subnet" {
  description = "The ID of the public subnet."
  value       = [for az in var.availability_zones : aws_subnet.public_subnet[az].id]
}

output "private_subnet" {
  description = "The ID of the private subnet."
  value       = [for az in var.availability_zones : aws_subnet.private_subnet[az].id]
}
