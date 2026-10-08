output "instance_id" {
  description = "ID de l'instance EC2."
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "IP publique de l'instance (Elastic IP)."
  value       = aws_instance.server.public_ip
}