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

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  instance_types = [var.node_instance_type]
  capacity_type = var.capacity_type
  ami_type      = var.ami_type

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.prod-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.prod-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.prod-node-AmazonEC2ContainerRegistryPullOnly,
  ]
}
