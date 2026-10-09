resource "aws_eks_cluster" "main" {
  name = var.cluster_name

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  role_arn = aws_iam_role.cluster.arn
  version  = var.eks_version

  vpc_config {
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access

    public_access_cidrs = var.public_access_cidrs

    subnet_ids = var.subnet_ids
  }
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
}

