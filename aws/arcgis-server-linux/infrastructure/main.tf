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
 * The module also creates an AWS backup plan for the deployment that backs up all the EC2 instances and EFS file system in the site's backup vault.
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
 * The module reads the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.alb_deployment_id}/alb/arn | ALB ARN (if alb_deployment_id is specified) |
 * | /arcgis/${var.site_id}/${var.alb_deployment_id}/alb/security-group-id | ALB security group Id (if alb_deployment_id is specified) |
 * | /arcgis/${var.site_id}/${var.alb_deployment_id}/deployment-fqdn | Fully qualified domain name of the base ArcGIS Enterprise deployment (if alb_deployment_id is specified) |
 * | /arcgis/${var.site_id}/${var.alb_deployment_id}/deployment-url | Portal for ArcGIS URL (if alb_deployment_id is specified) |
 * | /arcgis/${var.site_id}/backup/vault-name | Name of the AWS Backup vault |
 * | /arcgis/${var.site_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/node | Node EC2 instances AMI Id |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/primary | Primary EC2 instance AMI Id |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone Id |
 * | /arcgis/${var.site_id}/vpc/id | VPC Id |
 * | /arcgis/${var.site_id}/vpc/subnets | Ids of VPC subnets |
 *
 * The module writes the following SSM parameters:
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/arn | ARN of the application load balancer (if alb_deployment_id is not specified) |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name | DNS name of the application load balancer (if alb_deployment_id is not specified) |
 * | /arcgis/${var.site_id}/${var.deployment_id}/alb/security-group-id | Security group Id of the application load balancer (if alb_deployment_id is not specified) |
 * | /arcgis/${var.site_id}/${var.deployment_id}/backup-plan-id | Backup plan ID for the deployment | 
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the deployment |
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-url | ArcGIS Server URL |
 * | /arcgis/${var.site_id}/${var.deployment_id}/portal-url | Portal for ArcGIS URL |
 * | /arcgis/${var.site_id}/${var.deployment_id}/security-group-id | Deployment security group Id |
 * | /arcgis/${var.site_id}/${var.deployment_id}/server-web-context | ArcGIS Server web context |
 * | /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | ARN of SNS topic for deployment alarms |
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
    ArcGISRole = "fileserver"
  }
}

# Create EFS mount targets for the EFS file system in the deployment's subnets.
resource "aws_efs_mount_target" "fileserver" {
  count = length(local.subnets)
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
  ami                    = nonsensitive(data.aws_ssm_parameter.primary_ami.value)
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = module.site_core_info.instance_profile_name
  monitoring             = true


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
  count                  = var.node_count
  ami                    = nonsensitive(data.aws_ssm_parameter.node_ami.value)
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

# Create S3 bucket for the object store
resource "aws_s3_bucket" "object_store" {
  bucket_prefix = "${var.site_id}-object-store"
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
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/object-store-s3-bucket"
  type        = "String"
  value       = aws_s3_bucket.object_store.bucket
  description = "Object store S3 bucket"
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
