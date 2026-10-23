# Copyright 2024-2026 Esri
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
    key = "terraform/arcgis/arcgis-server-linux/infrastructure.tfstate"
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
  count = var.portal_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.portal_deployment_id}/deployment-url"
}

data "aws_ssm_parameter" "server_web_context" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context"
}

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.primary_ami.value]
  }
}

data "aws_ssm_parameter" "alb_ingress_fqdn" {
  name = "/arcgis/${var.enterprise_id}/${var.ingress_id}/ingress-fqdn"
}

data "aws_ssm_parameter" "alb_security_group_id" {
  name = "/arcgis/${var.enterprise_id}/${var.ingress_id}/alb/security-group-id"
}

data "aws_ssm_parameter" "alb_arn" {
  name = "/arcgis/${var.enterprise_id}/${var.ingress_id}/alb/arn"
}

data "aws_lb" "alb" {
  arn = data.aws_ssm_parameter.alb_arn.value
}

locals {
  subnets = (length(var.subnet_ids) == 0 ? module.enterprise_core_info.private_subnets : var.subnet_ids)

  # Get value of ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_version = try(data.aws_ami.ami.tags.ArcGISVersion, null)

  alb_security_group_id = nonsensitive(data.aws_ssm_parameter.alb_security_group_id.value)
  alb_arn               = nonsensitive(data.aws_ssm_parameter.alb_arn.value)
  alb_dns_name          = data.aws_lb.alb.dns_name
  ingress_fqdn          = nonsensitive(data.aws_ssm_parameter.alb_ingress_fqdn.value)
  server_web_context    = nonsensitive(data.aws_ssm_parameter.server_web_context.value)

  namespace = "${var.enterprise_id}${random_id.unique_name_suffix.hex}"
}

resource "random_id" "unique_name_suffix" {
  keepers = {
    enterprise_id = var.enterprise_id
    deployment_id = var.deployment_id
  }

  byte_length = 8
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
  alb_ports             = [80, 443, 6443]
}

resource "aws_ssm_parameter" "security_group_id" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group ID"
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
    Name              = "${var.enterprise_id}/${var.deployment_id}/node"
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "node"
  }

  volume_tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/node"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISMachineRole  = "node"
  }
}

# Create Application Load Balancer target group for HTTPS port 443, attach 
# primary and node instances to it, and add the target group to the load balancer. 
# Configure the target group to forward requests to the HTTP web context.
module "server_https_alb_target" {
  source            = "../../modules/alb_target_group"
  name              = substr(local.server_web_context, 0, 6)
  vpc_id            = module.enterprise_core_info.vpc_id
  alb_arn           = local.alb_arn
  protocol          = "HTTPS"
  alb_port          = 443
  instance_port     = 443
  health_check_path = "/${local.server_web_context}/rest/info/healthcheck"
  web_context       = local.server_web_context
  priority          = var.listener_rule_priority
  target_instances  = concat([aws_instance.primary.id], [for n in aws_instance.nodes : n.id])
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

# Create S3 bucket for the object store
resource "aws_s3_bucket" "object_store" {
  bucket        = "${local.namespace}-object-store"
  force_destroy = true

  tags = {
    ArcGISRole = "object-store"
  }
}

# Enable S3 bucket versioning required by AWS Backup
resource "aws_s3_bucket_versioning" "object_store" {
  bucket = aws_s3_bucket.object_store.id
  versioning_configuration {
    status = "Enabled"
  }
}

# AWS Backup S3 restores require the ability to set object ACLs.
resource "aws_s3_bucket_ownership_controls" "object_store" {
  bucket = aws_s3_bucket.object_store.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_ssm_parameter" "object_store_s3_bucket" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/object-store-s3-bucket"
  type        = "String"
  value       = aws_s3_bucket.object_store.bucket
  description = "Object store S3 bucket"
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

resource "aws_ssm_parameter" "namespace" {
  count       = var.ingress_id == null ? 0 : 1
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/namespace"
  type        = "String"
  value       = local.namespace
  description = "Namespace of the deployment used to generate unique resource names"
}

# Save the ALB DNS name to SSM parameter store for use by other modules.
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
  value       = "https://${local.ingress_fqdn}/${local.server_web_context}"
  description = "URL of the deployment"
}

# Save the Portal for ArcGIS URL to SSM parameter store for use by other modules.
resource "aws_ssm_parameter" "portal_url" {
  count       = var.portal_deployment_id == null ? 0 : 1
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/portal-url"
  type        = "String"
  value       = nonsensitive(data.aws_ssm_parameter.portal_deployment_url[0].value)
  description = "Portal for ArcGIS URL"
}
