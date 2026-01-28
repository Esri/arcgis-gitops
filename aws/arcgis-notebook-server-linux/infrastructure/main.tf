/**
 * # Infrastructure Terraform Module for ArcGIS Notebook Server on Linux
 *
 * The Terraform module provisions AWS resources for ArcGIS Notebook Server deployment on Linux platform.
 *
 * ![Infrastructure for ArcGIS Notebook Server on Linux](arcgis-notebook-server-linux-infrastructure.png "Infrastructure for ArcGIS Notebook Server on Linux")  
 *
 * The module launches a primary instance and N node instances (configurable via node_count)
 * SSM-managed EC2 instances in the private VPC subnets or subnets specified by subnet_ids input variable.
 * The instances are launched from images retrieved from '/arcgis/${var.site_id}/images/${var.deployment_id}/{instance role}' SSM parameters. 
 * The images must be created by the Packer Template for ArcGIS Notebook Server on Linux AMI. 
 *
 * For the primary EC2 instance the module creates "A" record in the VPC Route 53 private hosted zone
 * to make the instance addressable using a permanent DNS name.
 *
 * > Note that the EC2 instance will be terminated and recreated if the infrastructure terraform module
 *   is applied again after the SSM parameter value was modified by a new image build.
 *
 * A highly available EFS file system is created and mounted to the EC2 instances. 
 *
 * The module creates target groups that target the EC2 instances and associates 
 * the target groups with the deployment's load balancer listeners.
 *  
 * The deployment's Monitoring Subsystem consists of:
 *
 * * A CloudWatch log group
 * * CloudWatch agent on the EC2 instances that sends the system logs to the log group 
 *   as well as metrics for resource utilization on the EC2 instances.
 * * A CloudWatch dashboard that displays the CloudWatch metrics and logs of the deployment.
 *
 * The module also creates an AWS backup plan for the deployment that backs up all 
 * the EC2 instances and EFS file system in the site's backup vault.
 *
 * All the created AWS resources are tagged with ArcGISSiteId and ArcGISDeploymentId tags.
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed.
 * * Path to aws/scripts directory must be added to PYTHONPATH.
 * * AWS credentials must be configured.
 *
 * ## Troubleshooting
 *
 * Use Session Manager connection in AWS Console for SSH access to the EC2 instances.
 *
 * ## SSM Parameters
 *
 * The module reads the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.ingress_deployment_id}/alb/arn | ALB ARN |
 * | /arcgis/${var.site_id}/${var.ingress_deployment_id}/alb/security-group-id | ALB security group ID |
 * | /arcgis/${var.site_id}/${var.ingress_deployment_id}/deployment-fqdn | Fully qualified domain name of the ALB deployment |
 * | /arcgis/${var.site_id}/${var.portal_deployment_id}/deployment-url | Portal for ArcGIS URL |
 * | /arcgis/${var.site_id}/backup/vault-name | Name of the AWS Backup vault |
 * | /arcgis/${var.site_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/node | Node EC2 instances AMI ID |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/primary | Primary EC2 instance AMI ID |
 * | /arcgis/${var.site_id}/s3/backup | S3 bucket for the backup |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM command output |
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket for the private repository |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone ID |
 * | /arcgis/${var.site_id}/vpc/id | VPC ID |
 * | /arcgis/${var.site_id}/vpc/subnets | IDs of VPC subnets |
 *
 * The module writes the following SSM parameters:
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the deployment |
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-url | ArcGIS Notebook Server URL |
 * | /arcgis/${var.site_id}/${var.deployment_id}/notebook-server-web-context | ArcGIS Notebook Server web context |
 * | /arcgis/${var.site_id}/${var.deployment_id}/security-group-id | Deployment security group ID |
 * | /arcgis/${var.site_id}/${var.deployment_id}/portal-url | Portal for ArcGIS URL |
 */

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
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }
}

# Retrieve configuration parameters from SSM Parameter Store

data "aws_ssm_parameter" "primary_ami" {
  name = "/arcgis/${var.site_id}/images/${var.deployment_id}/primary"
}

data "aws_ssm_parameter" "node_ami" {
  name = "/arcgis/${var.site_id}/images/${var.deployment_id}/node"
}

data "aws_ssm_parameter" "portal_deployment_url" {
  name = "/arcgis/${var.site_id}/${var.portal_deployment_id}/deployment-url"
}

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [nonsensitive(data.aws_ssm_parameter.primary_ami.value)]
  }
}

locals {
  subnets = (length(var.subnet_ids) == 0 ? module.site_core_info.private_subnets : var.subnet_ids)

  # Get value of ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_version = try(data.aws_ami.ami.tags.ArcGISVersion, null)
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

# Create and configure the deployment's EC2 security group 
module "security_group" {
  source                = "../../modules/security_group"
  name                  = "${var.site_id}-${var.deployment_id}-app"
  vpc_id                = module.site_core_info.vpc_id
  alb_security_group_id = local.alb_security_group_id
  alb_ports             = [80, 443, 11443]
}

# Create EFS file system for the deployment's file server
resource "aws_efs_file_system" "fileserver" {
  encrypted = true

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/fileserver"
    ArcGISRole = "fileserver"
  }
}

# Create EFS mount targets for the EFS file system in the deployment's subnets.
resource "aws_efs_mount_target" "fileserver" {
  count           = length(local.subnets)
  file_system_id  = aws_efs_file_system.fileserver.id
  subnet_id       = local.subnets[count.index]
  security_groups = [module.security_group.id]
}

# Create network interface for the primary EC2 instance.
# This allows replacing EC2 instances from snapshot AMIs without changing the network interfaces.
resource "aws_network_interface" "primary" {
  subnet_id       = local.subnets[0]
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/primary"
  }
}

# Create primary EC2 instance
resource "aws_instance" "primary" {
  ami                  = nonsensitive(data.aws_ssm_parameter.primary_ami.value)
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = module.site_core_info.instance_profile_name
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
    Name              = "${var.site_id}/${var.deployment_id}/primary"
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "primary"
  }

  volume_tags = {
    Name               = "${var.site_id}/${var.deployment_id}/primary"
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISMachineRole  = "primary"
  }
}

resource "aws_network_interface" "nodes" {
  count           = var.node_count
  # Distribute node instances in different subnets starting from the second subnet.
  subnet_id       = local.subnets[(count.index + 1) % length(local.subnets)]
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/node/${count.index + 1}"
  }
}

# Create node EC2 instances
resource "aws_instance" "nodes" {
  count = var.node_count
  ami   = nonsensitive(data.aws_ssm_parameter.node_ami.value)
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true

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
    Name              = "${var.site_id}/${var.deployment_id}/node/${count.index + 1}"
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "node"
  }

  volume_tags = {
    Name               = "${var.site_id}/${var.deployment_id}/node/${count.index + 1}"
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISMachineRole  = "node"
  }
}

# Mount /mnt/efs/ to the EFS file system on the EC2 instances.
module "efs_mount" {
  source         = "../../modules/efs_mount"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  file_system_id = aws_efs_file_system.fileserver.id
  mount_point    = "/mnt/efs/"
  depends_on = [
    aws_efs_file_system.fileserver,
    aws_efs_mount_target.fileserver,
    aws_instance.primary,
    aws_instance.nodes
  ]
}

# Create Route53 record for the primary EC2 instance in the VPC private hosted zone.
resource "aws_route53_record" "primary" {
  zone_id = module.site_core_info.hosted_zone_id
  name    = "primary.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.primary.private_ip]
}

# Configure CloudWatch agent on the EC2 instances.
module "cw_agent" {
  source        = "../../modules/cw_agent"
  platform      = "linux"
  site_id       = var.site_id
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
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  log_group_name = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}

# Store deployment information in SSM Parameter Store

resource "aws_ssm_parameter" "security_group_id" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group Id"
}

resource "aws_ssm_parameter" "deployment_fqdn" {
  count       = var.ingress_deployment_id == null ? 0 : 1
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn"
  type        = "String"
  value       = local.deployment_fqdn
  description = "Fully qualified domain name of the deployment"
}

resource "aws_ssm_parameter" "notebook_server_web_context" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/notebook-server-web-context"
  type        = "String"
  value       = var.notebook_server_web_context
  description = "ArcGIS Notebook Server web context"
}

resource "aws_ssm_parameter" "deployment_url" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-url"
  type        = "String"
  value       = "https://${local.deployment_fqdn}/${var.notebook_server_web_context}"
  description = "ArcGIS Notebook Server URL"
}

resource "aws_ssm_parameter" "portal_url" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/portal-url"
  type        = "String"
  value       = nonsensitive(data.aws_ssm_parameter.portal_deployment_url.value)
  description = "Portal for ArcGIS URL"
}