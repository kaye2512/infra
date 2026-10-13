output "address" {
  description = "Nom DNS de la base (sans le port), à utiliser comme hôte de connexion."
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Port PostgreSQL."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nom de la base créée au démarrage."
  value       = aws_db_instance.main.db_name
}

output "username" {
  description = "Utilisateur administrateur de la base."
  value       = aws_db_instance.main.username
}

output "master_user_secret_arn" {
  description = "ARN du secret Secrets Manager qui contient le mot de passe administrateur."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group de la base, pour ajouter d'autres sources autorisées."
  value       = aws_security_group.rds.id
}