/**
 * # Infrastructure Terraform Module for base ArcGIS Enterprise on Windows
 *
 * The Terraform module creates AWS resources for highly available base ArcGIS Enterprise deployment on Windows platform.
 *
 * ![Base ArcGIS Enterprise on Windows / Infrastructure](arcgis-enterprise-base-windows-infrastructure.png "Base ArcGIS Enterprise on Windows / Infrastructure")
 *
 * The module launches three SSM managed EC2 instances in the private VPC subnets or subnets specified by subnet_ids input variable. 
 * The EC2 instances are launched from images retrieved from '/arcgis/${var.site_id}/images/${var.deployment_id}/{instance role}' SSM parameters. 
 * The images must be created by the Packer Template for Base ArcGIS Enterprise on Windows. 
 *
 * For the EC2 instances the module creates "A" records in the VPC Route53 private hosted zone to make the instances addressable using permanent DNS names.
 * 
 * > Note that the EC2 instance will be terminated and recreated if the infrastructure terraform module is applied again after the SSM parameter value was modified by a new image build.
 *
 * S3 buckets for the portal content and object store are created. The S3 buckets names are stored in the SSM parameters.
 *
 * The module creates an Application Load Balancer (ALB) with listeners for ports 80, 443, 6443, and 7443 and target groups for the listeners that target the EC2 instances.
 * Internet-facing load balancer is configured to use two of the public VPC subnets, while internal load balancer uses the private subnets.
 * The module also creates a private Route53 hosted zone for the deployment FQDN and an alias A record for the load balancer DNS name in the hosted zone.
 * This makes the deployment FQDN addressable from the VPC subnets.  
 *
 * The deployment's Monitoring Subsystem consists of:
 *
 * * An SNS topic and a CloudWatch alarms that monitor the target groups and post to the SNS topic if the number of unhealthy instances in nonzero. 
 * * A CloudWatch log group
 * * CloudWatch agent on the EC2 instances that sends the system and Chef run logs to the log group as well as memory and disk utilization on the EC2 instances. 
 * * A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and logs of the deployment.
 *
 * All the created AWS resources are tagged with ArcGISSiteId and ArcGISDeploymentId tags.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured
 *
 * Before creating the infrastructure, an SSL certificate for the base ArcGIS Enterprise deployment domain name 
 * must be imported into or issued by AWS Certificate Manager service in the AWS account. The certificate's
 * ARN specified by "ssl_certificate_arn" input variable will be used to configure HTTPS listeners of the load balancer.
 * 
 * After creating the infrastructure, the deployment FQDN also must be pointed to the DNS name of Application Load Balancer
 * exported by "alb_dns_name" output value of the module.
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
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/fileserver | Fileserver EC2 instance AMI Id |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/primary | Primary EC2 instance AMI Id |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/standby | Standby EC2 instance AMI Id |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/vpc/subnets | Ids of VPC subnets |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone Id |
 * | /arcgis/${var.site_id}/vpc/id | VPC Id |
 *
 * The module creates the following SSM parameters:
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/security-group-id | Deployment security group Id |
 * | /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | ARN of SNS topic for deployment alarms |
 * | /arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket | Portal for ArcGIS content store S3 bucket |
 * | /arcgis/${var.site_id}/${var.deployment_id}/object-store-s3-bucket | Object store S3 bucket |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/arn | ARN of the application load balancer (if alb_deployment_id is not specified) |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name | DNS name of the application load balancer (if alb_deployment_id is not specified) |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/security-group-id | Security group Id of the application load balancer (if alb_deployment_id is not specified) |
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
    key = "terraform/arcgis-enterprise/arcgis-enterprise-base/infrastructure.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
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

data "aws_ssm_parameter" "fileserver_ami" {
  name = "/arcgis/${var.site_id}/images/${var.deployment_id}/fileserver"
}

data "aws_ssm_parameter" "primary_ami" {
  name = "/arcgis/${var.site_id}/images/${var.deployment_id}/primary"
}

data "aws_ssm_parameter" "standby_ami" {
  name = "/arcgis/${var.site_id}/images/${var.deployment_id}/standby"
}

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.primary_ami.value]
  }
}

locals {
  primary_subnet = length(var.subnet_ids) < 2 ? module.site_core_info.private_subnets[0] : var.subnet_ids[0]  
  standby_subnet = length(var.subnet_ids) < 2 ? module.site_core_info.private_subnets[1] : var.subnet_ids[1]

  # Get values of ArcGISTemplateId and ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_template_id = "arcgis-enterprise-base"
  arcgis_version     = try(data.aws_ami.ami.tags.ArcGISVersion, null)
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
  alb_security_group_id = module.alb.security_group_id
  alb_ports             = [80, 443, 6443, 7443]
}

resource "aws_ssm_parameter" "security_group_id" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group Id"
}

resource "aws_network_interface" "fileserver" {
  subnet_id = local.primary_subnet
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/fileserver"
  }
}

# Create fileserver EC2 instance
resource "aws_instance" "fileserver" {
  ami                    = data.aws_ssm_parameter.fileserver_ami.value
  instance_type          = var.fileserver_instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true

  network_interface {
    network_interface_id = aws_network_interface.fileserver.id
    device_index         = 0
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.fileserver_volume_size
    encrypted   = true
    iops        = var.fileserver_volume_iops
    throughput  = var.fileserver_volume_throughput
  }

  tags = {
    Name              = "${var.site_id}/${var.deployment_id}/fileserver"
    ArcGISTemplateId  = local.arcgis_template_id
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "fileserver"
  }

  volume_tags = {
    Name               = "${var.site_id}/${var.deployment_id}/fileserver"
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISMachineRole  = "fileserver"
  }
}

resource "aws_network_interface" "primary" {
  subnet_id = local.primary_subnet
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/primary"
  }
}

# Create primary EC2 instance
resource "aws_instance" "primary" {
  ami                    = nonsensitive(data.aws_ssm_parameter.primary_ami.value)
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true

  network_interface {
    network_interface_id = aws_network_interface.primary.id
    device_index         = 0
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
    ArcGISTemplateId  = local.arcgis_template_id
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

resource "aws_network_interface" "standby" {
  subnet_id = local.standby_subnet
  # private_ips    = ["10.0.65.XXX"]  
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.site_id}/${var.deployment_id}/standby"
  }
}

# Create standby EC2 instance
resource "aws_instance" "standby" {
  ami                    = nonsensitive(data.aws_ssm_parameter.standby_ami.value)
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true

  network_interface {
    network_interface_id = aws_network_interface.standby.id
    device_index         = 0
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
    Name              = "${var.site_id}/${var.deployment_id}/standby"
    ArcGISTemplateId  = local.arcgis_template_id
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "standby"
  }

  volume_tags = {
    Name               = "${var.site_id}/${var.deployment_id}/standby"
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISMachineRole  = "standby"
  }
}

resource "aws_route53_record" "fileserver" {
  zone_id = module.site_core_info.hosted_zone_id
  name    = "fileserver.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.fileserver.private_ip]
}

resource "aws_route53_record" "primary" {
  zone_id = module.site_core_info.hosted_zone_id
  name    = "primary.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.primary.private_ip]
}

resource "aws_route53_record" "standby" {
  zone_id = module.site_core_info.hosted_zone_id
  name    = "standby.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.standby.private_ip]
}

# Create S3 bucket for the portal content
resource "aws_s3_bucket" "portal_content" {
  bucket_prefix = "${var.site_id}-portal-content"
  force_destroy = true
}

resource "aws_ssm_parameter" "portal_content_s3_bucket" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket"
  type        = "String"
  value       = aws_s3_bucket.portal_content.bucket
  description = "Portal for ArcGIS content store S3 bucket"
}

# Create S3 bucket for the object store
resource "aws_s3_bucket" "object_store" {
  bucket_prefix = "${var.site_id}-object-store"
  force_destroy = true
}

resource "aws_ssm_parameter" "object_store_s3_bucket" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/object-store-s3-bucket"
  type        = "String"
  value       = aws_s3_bucket.object_store.bucket
  description = "Object store S3 bucket"
}

module "cw_agent" {
  source        = "../../modules/cw_agent"
  platform      = "windows"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  depends_on = [
    aws_instance.fileserver,
    aws_instance.primary,
    aws_instance.standby
  ]
}

module "dashboard" {
  source        = "../../modules/dashboard"
  platform      = "windows"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  alb_arn       = module.alb.alb_arn
  log_group_name = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}
