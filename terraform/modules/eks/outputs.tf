output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "URL for Kubernetes API."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificate for Kubernetes API, used by kubectl to verify the server."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group created by EKS (will be used to allow access from the bastion)."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster (will be used to grant AWS permissions to pods)."
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}