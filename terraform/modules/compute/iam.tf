data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bastion_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "bastion_permissions" {
  statement {
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.environment}-*"
    ]
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.environment}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role.json
}

resource "aws_iam_role_policy" "bastion_eks" {
  name   = "eks-describe-cluster"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.bastion_permissions.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.environment}-bastion-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role_policy" "bastion_ecr" {
  name = "${var.environment}-bastion-ecr-push"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Le jeton de connexion vaut pour tout le registre du compte :
        # AWS n'accepte pas de le limiter à un dépôt.
        Sid      = "EcrLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Push (et pull, pour réutiliser les couches en cache) sur NOTRE dépôt uniquement
        Sid    = "EcrPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = var.ecr_repository_arn
      }
    ]
  })
}