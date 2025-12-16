/**
 * # Terraform Module K8s-cluster
 *
 * The Terraform module provisions Amazon Elastic Kubernetes Service (EKS) cluster
 * that meets [ArcGIS Enterprise on Kubernetes system requirements](https://enterprise-k8s.arcgis.com/en/latest/deploy/configure-aws-for-use-with-arcgis-enterprise-on-kubernetes.htm).
 *
 * The module installs the following add-ons to the EKS cluster:
 *
 * * Load Balancer Controller add-on
 * * Amazon EBS CSI Driver add-on
 * * Amazon CloudWatch Observability EKS add-on
 *
 * Optionally, the module also configures pull through cache rules for Amazon Elastic Container Registry (ECR) 
 * to sync the contents of source Docker Hub and Public Amazon ECR registries with private Amazon ECR registry.
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
 * If subnet IDs of the EKS cluster and node groups are not specified by input variables,
 * the subnet IDs are retrieved from the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/vpc/subnets | Ids of VPC subnets |
 */

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

terraform {
  backend "s3" {
    key = "arcgis-enterprise/aws/k8s-cluster.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 3.0"
    }
  }

  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ArcGISAutomation = "arcgis-gitops"      
      ArcGISSiteId     = var.site_id
    }
  }
}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.cluster.identity.0.oidc.0.issuer
}

locals {
  containerinsights_log_groups = [
    "application",
    "dataplane",
    "host",
    "performance"
  ]
}

module "site_core_info" {
  source = "../../modules/site_core_info"
  site_id = var.site_id
}

# Create Key Management Service (KMS) key.
resource "aws_kms_key" "eks" {
  description = "EKS encryption key"
}

# Create CloudWatch log group /aws/eks/<cluster-name>/cluster
# See: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
# resource "aws_cloudwatch_log_group" "eks_cluster" {
#   name              = "/aws/eks/${var.site_id}/cluster"
#   retention_in_days = 7
# }

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
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids = length(var.subnet_ids) < 2 ? concat(
      module.site_core_info.public_subnets,
      module.site_core_info.private_subnets,
      module.site_core_info.internal_subnets
    ) : var.subnet_ids
  }

  # enabled_cluster_log_types = ["api"]

  # depends_on = [
  #   aws_cloudwatch_log_group.eks_cluster
  # ]
}

# Pre-create CloudWatch log groups for the Amazon CloudWatch Observability EKS add-on.
# Note that the log groups created by CloudWatch agent on demand have retention set to "Never Expire" and 
# are not deleted when the the EKS cluster is deleted.
resource "aws_cloudwatch_log_group" "containerinsights" {
  count = length(local.containerinsights_log_groups)
  name              = "/aws/containerinsights/${aws_eks_cluster.cluster.name}/${local.containerinsights_log_groups[count.index]}"
  retention_in_days = var.containerinsights_log_retention

  depends_on = [ 
    aws_eks_cluster.cluster
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
    
    # By default, EKS nodes use IMDSv2 with a hop limit of 1.
    # The hop limit greater than 1 is required to allow containers access to IMDSv2.
    http_put_response_hop_limit = 2
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

  # Use the first two private subnets if the subnets list of the node group 
  # contains less then 2 elements.
  subnet_ids = (length(var.node_groups[count.index].subnet_ids) < 2 ?
    module.site_core_info.private_subnets :
  var.node_groups[count.index].subnet_ids)

  launch_template {
    id      = aws_launch_template.node_groups[count.index].id
    version = "$Latest"
  }

  scaling_config {
    desired_size = var.node_groups[count.index].desired_size
    max_size     = var.node_groups[count.index].max_size
    min_size     = var.node_groups[count.index].min_size
  }

  depends_on = [
    aws_cloudwatch_log_group.containerinsights
  ]
}

# Install the Load Balancer Controller add-on.
module "load_balancer_controller" {
  source = "./modules/load-balancer-controller"

  cluster_name = aws_eks_cluster.cluster.name
  oidc_arn     = aws_iam_openid_connect_provider.eks_oidc.arn
  enable_waf   = var.enable_waf
  copy_image   = !var.pull_through_cache
  vpc_id       = module.site_core_info.vpc_id

  depends_on = [
    aws_eks_node_group.node_groups
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

# Install the Amazon CloudWatch Observability EKS add-on.
module "cloudwatch_observability" {
  source = "./modules/cloudwatch-observability"
  cluster_name = aws_eks_cluster.cluster.name
  container_logs_enabled = true
  
  depends_on = [
    module.ebs_csi_driver
  ]  
}

# Configure pull through cache rules for Amazon ECR

resource "aws_secretsmanager_secret" "aws_ecrpullthroughcache" {
  count                   = var.pull_through_cache ? 1 : 0
  name                    = "ecr-pullthroughcache/${var.site_id}"
  description             = "Secret for ECR pull-through cache"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "aws_ecrpullthroughcache" {
  count     = var.pull_through_cache ? 1 : 0
  secret_id = aws_secretsmanager_secret.aws_ecrpullthroughcache[0].id
  secret_string = jsonencode({
    username    = var.container_registry_user
    accessToken = var.container_registry_password
    }
  )
}

resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  count                 = var.pull_through_cache ? 1 : 0
  ecr_repository_prefix = var.ecr_repository_prefix
  upstream_registry_url = var.container_registry_url
  credential_arn        = aws_secretsmanager_secret.aws_ecrpullthroughcache[0].arn
}

resource "aws_ecr_pull_through_cache_rule" "public_ecr" {
  count                 = var.pull_through_cache ? 1 : 0
  ecr_repository_prefix = "ecr-public"
  upstream_registry_url = "public.ecr.aws"
}
