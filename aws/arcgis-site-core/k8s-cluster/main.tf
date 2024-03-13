/**
 * # Terraform Module K8s-cluster
 *
 * The Terraform module provisions Amazon Elastic Kubernetes Service (EKS) cluster
 * that meets ArcGIS Enterprise on Kubernetes system requirements.
 *
 * See: https://enterprise-k8s.arcgis.com/en/latest/deploy/configure-aws-for-use-with-arcgis-enterprise-on-kubernetes.htm
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 *
 * * AWS credentials and default region must be configured.
 * * AWS CLI, kubectl, and helm must be installed.
 *
 * ## SSM Parameters
 *
 * The module uses the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/vpc/private-subnet-1 | Private VPC subnet 1 Id |
 * | /arcgis/${var.site_id}/vpc/private-subnet-2 | Private VPC subnet 2 Id |
 * | /arcgis/${var.site_id}/vpc/public-subnet-1 | Public VPC subnet 1 Id |
 * | /arcgis/${var.site_id}/vpc/public-subnet-2 | Public VPC subnet 2 Id |
 */

terraform {
  backend "s3" {
    key = "arcgis-enterprise/aws/k8s-cluster.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.1.9"
}

provider "aws" {
  default_tags {
    tags = {
      ArcGISSiteId       = var.site_id
    }
  }
}

data "aws_ssm_parameter" "public_subnet1" {
  name = "/arcgis/${var.site_id}/vpc/public-subnet-1"
}

data "aws_ssm_parameter" "public_subnet2" {
  name = "/arcgis/${var.site_id}/vpc/public-subnet-2"
}

data "aws_ssm_parameter" "private_subnet1" {
  name = "/arcgis/${var.site_id}/vpc/private-subnet-1"
}

data "aws_ssm_parameter" "private_subnet2" {
  name = "/arcgis/${var.site_id}/vpc/private-subnet-2"
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.cluster.identity.0.oidc.0.issuer
}

# Create Key Management Service (KMS) key.
resource "aws_kms_key" "eks" {
  description = "EKS encryption key"
}

# Create CloudWatch log group /aws/eks/<cluster-name>/cluster
# See: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.site_id}/cluster"
  retention_in_days = 7
}

# Create an EKS cluster
resource "aws_eks_cluster" "cluster" {
  name     = var.site_id
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids = [
      data.aws_ssm_parameter.public_subnet1.value,
      data.aws_ssm_parameter.public_subnet2.value,
      data.aws_ssm_parameter.private_subnet1.value,
      data.aws_ssm_parameter.private_subnet2.value
    ]
  }

  enabled_cluster_log_types = ["api", "audit"]

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster
  ]
}

resource "aws_launch_template" "node_groups" {
  count = length(var.node_groups)
  name  = "${aws_eks_cluster.cluster.name}-${var.node_groups[count.index].name}-node-group"

  instance_type = var.node_groups[count.index].instance_type

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.node_groups[count.index].root_volume_size
      volume_type = "gp3"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  key_name = var.key_name

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${aws_eks_cluster.cluster.name}-${var.node_groups[count.index].name}-node"
    }
  }
}

# Create node groups
resource "aws_eks_node_group" "node_groups" {
  count           = length(var.node_groups)
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = var.node_groups[count.index].name
  node_role_arn   = aws_iam_role.eks_worker_node_role.arn
  subnet_ids = [
    data.aws_ssm_parameter.private_subnet1.value,
    data.aws_ssm_parameter.private_subnet2.value
  ]

  launch_template {
    id = aws_launch_template.node_groups[count.index].id
    version = "$Latest"
  }

  scaling_config {
    desired_size = var.node_groups[count.index].desired_size
    max_size     = var.node_groups[count.index].max_size
    min_size     = var.node_groups[count.index].min_size
  }
}

# Install the Load Balancer Controller add-on.
module "load_balancer_controller" {
  source = "./modules/load-balancer-controller"

  cluster_name = aws_eks_cluster.cluster.name
  oidc_arn     = aws_iam_openid_connect_provider.eks_oidc.arn

  depends_on = [
    aws_eks_cluster.cluster
  ]
}

# Install the Amazon EBS CSI Driver add-on.
module "ebs_csi_driver" {
  source = "./modules/ebs-csi-driver"

  cluster_name = aws_eks_cluster.cluster.name
  oidc_arn     = aws_iam_openid_connect_provider.eks_oidc.arn

  depends_on = [
    module.load_balancer_controller
  ]
}
