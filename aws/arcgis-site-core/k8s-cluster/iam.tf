# data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  oidc_provider = "oidc.eks.${data.aws_region.current.name}.amazonaws.com/id/${split("/", aws_iam_openid_connect_provider.eks_oidc.arn)[3]}"
  is_gov_cloud = contains(["us-gov-east-1", "us-gov-west-1"], data.aws_region.current.name)
  arn_identifier = local.is_gov_cloud ? "aws-us-gov" : "aws"  
}

### IAM OpenID Connect provider for EKS
resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates.0.sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity.0.oidc.0.issuer
}

# IAM role that provides permissions for the Kubernetes control plane to make 
# calls to AWS API operations.
resource "aws_iam_role" "eks_cluster_role" {
  name_prefix = "EKSClusterRole"
  description = "Permissions required by EKS cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["eks.amazonaws.com"]
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonEKSClusterPolicy"
  ]

  tags = {
    Name = "${var.site_id}/eks-cluster-role"
  }
}

# IAM role that provides permissions for the EKS Node Groups.
resource "aws_iam_role" "eks_worker_node_role" {
  name_prefix = "EKSWorkerNodeRole"
  description = "Permissions required by EKS workers"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ssm.amazonaws.com"
          ]
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:${local.arn_identifier}:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonS3FullAccess"
  ]

  tags = {
    Name = "${var.site_id}/eks-worker-role"
  }
}
