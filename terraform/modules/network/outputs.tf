output "main_vpc" {
  description = "The ID of the VPC."
  value       = aws_vpc.main_vpc.id
}

output "public_subnet" {
  description = "The ID of the public subnet."
  value       = aws_subnet.public_subnet.id
}

output "private_subnet" {
  description = "The ID of the private subnet."
  value       = aws_subnet.private_subnet.id
}
