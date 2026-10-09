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