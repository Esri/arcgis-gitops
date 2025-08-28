# Copyright 2024-2025 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  oidc_provider = "oidc.eks.${data.aws_region.current.region}.amazonaws.com/id/${split("/", aws_iam_openid_connect_provider.eks_oidc.arn)[3]}"
  is_gov_cloud = contains(["us-gov-east-1", "us-gov-west-1"], data.aws_region.current.region)
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

  tags = {
    Name = "${var.site_id}/eks-cluster-role"
  }
}

# IAM role policy attachment for the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:${local.arn_identifier}:iam::aws:policy/AmazonEKSClusterPolicy"
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

  tags = {
    Name = "${var.site_id}/eks-worker-role"
  }
}

# IAM role policy attachments
resource "aws_iam_role_policy_attachment" "policies" {
  count      = length(var.eks_worker_node_role_policies)
  role       = aws_iam_role.eks_worker_node_role.name
  policy_arn = var.eks_worker_node_role_policies[count.index]
}
