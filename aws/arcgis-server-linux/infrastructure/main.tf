/**
 * # Infrastructure Terraform Module for ArcGIS Server on Linux
 *
 * The Terraform module provisions AWS resources for highly available ArcGIS Server deployment on Linux platform.
 *
 * ![Infrastructure for ArcGIS Server on Linux](arcgis-server-linux-infrastructure.png "Infrastructure for ArcGIS Server on Linux")  
 *
 * The module launches two SSM managed EC2 instances in the private VPC subnets or subnets specified by subnet_ids input variable.
 * The instances are launched from image retrieved from '/arcgis/${var.site_id}/images/${var.deployment_id}/{instance role}' SSM parameter. 
 * The image must be created by the Packer Template for ArcGIS Server on Linux AMI. 
 *
 * For the primary EC2 instances the module creates "A" record in the VPC Route53 private hosted zone
 * to make the instance addressable using permanent DNS names.
 *
 * > Note that the EC2 instance will be terminated and recreated if the infrastructure terraform module
 *   is applied again after the SSM parameter value was modified by a new image build.
 *
 * A highly available EFS file system is created and mounted to the EC2 instances. 
 *
 * If alb_deployment_id input variable is null, the module creates and configure an Application Load Balancer (ALB) for the deployment. 
 * Otherwise, the it uses the ALB from deployment specified by alb_deployment_id and ignores the values of client_cidr_blocks, deployment_fqdn, hosted_zone_id, internal_load_balancer, ssl_certificate_arn, and ssl_policy input variables.
 * Internet-facing load balancer is configured to use two of the public VPC subnets, while internal load balancer uses the private subnets.
 * 
 * For the ALB the module creates target groups that target the EC2 instances. The target group for port 443 is always created. While the target group for port 6443 is created only if use_webadaptor input variable is set to false.
 * 
 * By default the HTTPS listener on port 443 is forwarded to instance port 6443. Set the use_webadaptor input variable to true, to use port 443.
 *  
 * The deployment's Monitoring Subsystem consists of:
 *
 * * An SNS topic and a CloudWatch alarms that monitor the target groups and post to the SNS topic if the number of unhealthy instances in nonzero. 
 * * A CloudWatch log group
 * * CloudWatch agent on the EC2 instances that sends the system logs to the log group as well as metrics fo resource utilization on the EC2 instances.
 * * A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and logs of the deployment.
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
 * If alb_deployment_id is not set:
 *
 * * Before creating the infrastructure, an SSL certificate for the ArcGIS Server deployment FQDN 
 *   must be imported into or issued by AWS Certificate Manager service in the AWS account. The certificate's
 *   ARN specified by "ssl_certificate_arn" input variable will be used to configure HTTPS listeners of the load balancer.
 * * After creating the infrastructure, the deployment FQDN must be pointed to the DNS name of Application Load Balancer
 *   exported by "alb_dns_name" output value of the module.
 *
 * ## Troubleshooting
 *
 * Use Session Manager connection in AWS Console for SSH access to the EC2 instances.
 *
 * The SSM commands output stored in the logs S3 bucket is copied in the Terraform stdout.
 * 
 * ## SSM Parameters
 *
 * The module uses the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.alb_deployment_id}/alb/arn | LBB ARN (if alb_deployment_id is specified) |
 * | /arcgis/${var.site_id}/${var.alb_deployment_id}/alb/security-group-id | ALB security group Id (if alb_deployment_id is specified) |
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/primary | Primary EC2 instance AMI Id |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/node | Node EC2 instances AMI Id |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/vpc/subnets | Ids of VPC subnets |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone Id |
 * | /arcgis/${var.site_id}/vpc/id | VPC Id |
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
    key = "terraform/arcgis-enterprise/arcgis-server/infrastructure.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.48"
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

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.primary_ami.value]
  }
}

locals {
  subnets = (length(var.subnet_ids) == 0 ? module.site_core_info.private_subnets : var.subnet_ids)

  # Get value of ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_version     = try(data.aws_ami.ami.tags.ArcGISVersion, null)
}

module "site_core_info" {
  source = "../../modules/site_core_info"
  site_id = var.site_id
}

# Create and configure the deployment's EC2 security group 
module "security_group" {
  source                = "../../modules/security_group"
  name                  = "${var.site_id}-${var.deployment_id}-app"
  vpc_id                = module.site_core_info.vpc_id
  alb_security_group_id = local.alb_security_group_id
  alb_ports             = [80, 443, 6443]
}

resource "aws_ssm_parameter" "security_group_id" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group Id"
}

# Create EFS file system for the deployment's file server
resource "aws_efs_file_system" "fileserver" {
  encrypted = true

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/fileserver"
  }
}

# Create EFS mount targets for the EFS file system in the deployment's subnets.
resource "aws_efs_mount_target" "fileserver" {
  count = length(local.subnets)
  file_system_id  = aws_efs_file_system.fileserver.id
  subnet_id       = local.subnets[count.index]
  security_groups = [module.security_group.id]
}

# Create primary EC2 instance
resource "aws_instance" "primary" {
  ami                    = nonsensitive(data.aws_ssm_parameter.primary_ami.value)
  subnet_id              = local.subnets[0]
  vpc_security_group_ids = [module.security_group.id]
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true

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

# Create node EC2 instances
resource "aws_instance" "nodes" {
  count                  = var.node_count
  ami                    = nonsensitive(data.aws_ssm_parameter.node_ami.value)
  # Distribute node instances in different subnets starting from the second subnet.
  subnet_id              = local.subnets[(count.index + 1) % length(local.subnets)]
  vpc_security_group_ids = [module.security_group.id]
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true

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
    Name              = "${var.site_id}/${var.deployment_id}/node"
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "node"
  }

  volume_tags = {
    Name               = "${var.site_id}/${var.deployment_id}/node"
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISMachineRole  = "node"
  }
}

# Mount /mnt/efs/ to the EFS file system on the EC2 instances.
module "nfs_mount" {
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.efs_mount"
  external_vars = {
    mount_point  = "/mnt/efs/"
    file_system_id = aws_efs_file_system.fileserver.id
  }
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
  source        = "../../modules/dashboard"
  platform      = "linux"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  alb_arn       = local.alb_arn
  log_group_name = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}
