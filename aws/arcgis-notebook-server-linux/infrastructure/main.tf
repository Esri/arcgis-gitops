# Copyright 2025-2026 Esri
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
    key = "terraform/arcgis-enterprise/arcgis-notebook-server/infrastructure.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }

  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ArcGISAutomation   = "arcgis-gitops"
      ArcGISEnterpriseID = var.enterprise_id
      ArcGISDeploymentID = var.deployment_id
    }
  }
}

# Retrieve configuration parameters from SSM Parameter Store
data "aws_ssm_parameter" "primary_ami" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary"
}

data "aws_ssm_parameter" "node_ami" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/node"
}

data "aws_ssm_parameter" "portal_deployment_url" {
  name = "/arcgis/${var.enterprise_id}/${var.portal_deployment_id}/deployment-url"
}

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [nonsensitive(data.aws_ssm_parameter.primary_ami.value)]
  }
}

locals {
  # Get value of ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_version = try(data.aws_ami.ami.tags.ArcGISVersion, null)
  namespace = "${var.enterprise_id}${random_id.unique_name_suffix.hex}"
  subnets = (length(var.subnet_ids) == 0 ? module.enterprise_core_info.private_subnets : var.subnet_ids)
}

resource "random_id" "unique_name_suffix" {
  keepers = {
    enterprise_id = var.enterprise_id
    deployment_id = var.deployment_id
  }

  byte_length = 8
}

resource "aws_ssm_parameter" "namespace" {
  count       = var.ingress_id == null ? 0 : 1
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/namespace"
  type        = "String"
  value       = local.namespace
  description = "Namespace of the deployment used to generate unique resource names"
}

module "enterprise_core_info" {
  source        = "../../modules/enterprise_core_info"
  enterprise_id = var.enterprise_id
}

# Create and configure the deployment's EC2 security group 
module "security_group" {
  source                = "../../modules/security_group"
  name                  = "${var.enterprise_id}-${var.deployment_id}-app"
  vpc_id                = module.enterprise_core_info.vpc_id
  alb_security_group_id = local.alb_security_group_id
  alb_ports             = [80, 443, 11443]
}

# Create network interface for the primary EC2 instance.
# This allows replacing EC2 instances from snapshot AMIs without changing the network interfaces.
resource "aws_network_interface" "primary" {
  subnet_id       = local.subnets[0]
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.enterprise_id}/${var.deployment_id}/primary"
  }
}

# Create primary EC2 instance
resource "aws_instance" "primary" {
  ami                  = nonsensitive(data.aws_ssm_parameter.primary_ami.value)
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = module.enterprise_core_info.instance_profile_name
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.primary.id
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    iops        = var.root_volume_iops
    throughput  = var.root_volume_throughput
  }

  tags = {
    Name              = "${var.enterprise_id}/${var.deployment_id}/primary"
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "primary"
  }

  volume_tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/primary"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISMachineRole  = "primary"
  }
}

resource "aws_network_interface" "nodes" {
  count = var.node_count
  # Distribute node instances in different subnets starting from the second subnet.
  subnet_id       = local.subnets[(count.index + 1) % length(local.subnets)]
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.enterprise_id}/${var.deployment_id}/node/${count.index + 1}"
  }
}

# Create node EC2 instances
resource "aws_instance" "nodes" {
  count                = var.node_count
  ami                  = nonsensitive(data.aws_ssm_parameter.node_ami.value)
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = module.enterprise_core_info.instance_profile_name
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.nodes[count.index].id
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    iops        = var.root_volume_iops
    throughput  = var.root_volume_throughput
  }

  tags = {
    Name              = "${var.enterprise_id}/${var.deployment_id}/node/${count.index + 1}"
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "node"
  }

  volume_tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/node/${count.index + 1}"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISMachineRole  = "node"
  }
}

# Create EFS file system or reference existing EFS file system for the deployment's file server.
# If fileserver_deployment_id is not specified, a new EFS file system will be created for this deployment. 
# Otherwise, the module will attempt to retrieve the file system ID and 
# security group ID from SSM parameters of the specified deployment.
module "efs_fileserver" {
  source                       = "../../modules/efs_fileserver"
  enterprise_id                = var.enterprise_id
  deployment_id                = var.deployment_id
  fileserver_deployment_id     = var.fileserver_deployment_id
  referenced_security_group_id = module.security_group.id
  subnet_ids                   = local.subnets
  vpc_id                       = module.enterprise_core_info.vpc_id
}

# Mount /mnt/efs/ to the EFS file system on the EC2 instances.
module "efs_mount" {
  source         = "../../modules/efs_mount"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  file_system_id = module.efs_fileserver.file_system_id
  mount_point    = "/mnt/efs/"
  depends_on = [
    module.efs_fileserver,
    aws_instance.primary,
    aws_instance.nodes
  ]
}

# Create Route53 record for the primary EC2 instance in the VPC private hosted zone.
resource "aws_route53_record" "primary" {
  zone_id = module.enterprise_core_info.hosted_zone_id
  name    = "primary.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.primary.private_ip]
}

# Configure CloudWatch agent on the EC2 instances.
module "cw_agent" {
  source        = "../../modules/cw_agent"
  platform      = "linux"
  enterprise_id = var.enterprise_id
  deployment_id = var.deployment_id
  depends_on = [
    aws_instance.primary,
    aws_instance.nodes
  ]
}

# Create CloudWatch dashboard for the deployment.
module "dashboard" {
  source         = "../../modules/dashboard"
  platform       = "linux"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  log_group_name = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}

# Store deployment information in SSM Parameter Store

resource "aws_ssm_parameter" "security_group_id" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group ID"
}

resource "aws_ssm_parameter" "ingress_fqdn" {
  count       = var.ingress_id == null ? 0 : 1
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/ingress-fqdn"
  type        = "String"
  value       = local.ingress_fqdn
  description = "Fully qualified domain name of the ingress"
}

resource "aws_ssm_parameter" "deployment_url" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/deployment-url"
  type        = "String"
  value       = "https://${local.ingress_fqdn}/${local.notebook_server_web_context}"
  description = "ArcGIS Notebook Server URL"
}

resource "aws_ssm_parameter" "portal_url" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/portal-url"
  type        = "String"
  value       = nonsensitive(data.aws_ssm_parameter.portal_deployment_url.value)
  description = "Portal for ArcGIS URL"
}
