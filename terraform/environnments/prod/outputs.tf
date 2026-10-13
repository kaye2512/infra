output "bastion_instance_id" {
  description = "ID de l'instance bastion."
  value       = module.compute.instance_id
}

output "bastion_public_ip" {
  description = "IP publique du bastion."
  value       = module.compute.public_ip
}

output "bastion_ssh_command" {
  description = "Commande SSH prête à l'emploi pour se connecter au bastion."
  value       = "ssh ${var.username}@${module.compute.public_ip}"
}

output "eks_kubeconfig_command" {
  description = "Command to generate the kubeconfig file for the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  description = "URL du dépôt ECR, pour docker push et les manifestes Kubernetes."
  value       = module.registry.repository_url
}

output "rds_address" {
  description = "Hôte PostgreSQL."
  value       = module.rds.address
}

output "rds_secret_arn" {
  description = "ARN du secret contenant le mot de passe de la base."
  value       = module.rds.master_user_secret_arn
}

output "rds_get_password_command" {
  description = "Commande pour afficher le mot de passe de la base (depuis le PC)."
  value       = "aws secretsmanager get-secret-value --region ${var.aws_region} --secret-id '${module.rds.master_user_secret_arn}' --query SecretString --output text"
}

output "rds_psql_command" {
  description = "Commande pour tester la connexion depuis un pod du cluster."
  value       = "kubectl run psql --rm -it --image=postgres:${var.engine_version} -- psql -h ${module.rds.address} -U ${module.rds.username} -d ${module.rds.db_name}"
}