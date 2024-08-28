/**
 * # Infrastructure Terraform Module for ArcGIS Server on Windows
 *
 * The Terraform module creates AWS resources for ArcGIS Server deployment on Windows platform.
 *
 * ![ArcGIS Server on Windows / Infrastructure](arcgis-server-windows-infrastructure.png "ArcGIS Server on Windows / Infrastructure")
 *
 * The module launches several SSM managed EC2 instances in the private VPC subnets or subnets specified by subnet_ids input variable. 
 * The primary and node instances are launched from image retrieved from '/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}' SSM parameter. 
 * The fileserver instance is launched from image retrieved from '/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver' SSM parameter. 
 *
 * For primary and fileserver EC2 instances the module creates "A" records in the VPC Route53 private hosted zone to make the instances addressable using permanent DNS names.
 * 
 * > Note that the EC2 instance will be terminated and recreated if the infrastructure terraform module is applied again after the SSM parameter value was modified by a new image build.
 *
 * The module creates an Application Load Balancer (ALB) with listeners for ports 80, 443, and 6443 and target groups for the listeners that target the EC2 instances.
 * Internet-facing load balancer is configured to use two of the public VPC subnets, while internal load balancer uses the private subnets.
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
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 *
 * Before creating the infrastructure, an SSL certificate for the ArcGIS Server deployment domain name 
 * must be imported into or issued by AWS Certificate Manager service in the AWS account. The certificate's
 * ARN specified by "ssl_certificate_arn" input variable will be used to configure HTTPS listeners of the load balancer.
 * 
 * If deployment_fqdn and hosted_zone_id input variables are specified, 
 * the module creates CNAME records in the hosted zone that routes the deployment FQDN to the load balancer DNS name. 
 * Otherwise, after creating the infrastructure, the domain name must be pointed to the DNS name of Application Load Balancer
 * exported by "alb_dns_name" output value of the module.
 *
 * > Note that a hosted zone can contain only one record for each domain name. Use different hosted zones for multiple deployments 
 *   with the same deployment_fqdn, or configure the DNS records outside of the module.
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
 * | /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver | Id of the fileserver AMI |
 * | /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id} | Id of the main AMI |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/vpc/public-subnet-1 | public VPC subnet 1 Id |
 * | /arcgis/${var.site_id}/vpc/public-subnet-2 | public VPC subnet 2 Id |
 * | /arcgis/${var.site_id}/vpc/private-subnet-1 | private VPC subnet 1 Id |
 * | /arcgis/${var.site_id}/vpc/private-subnet-2 | private VPC subnet 2 Id |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone Id |
 * | /arcgis/${var.site_id}/vpc/id | VPC Id |
 */

# Copyright 2024 Esri
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
      version = "~> 5.22"
    }
  }

  required_version = ">= 1.1.9"
}

provider "aws" {
  default_tags {
    tags = {
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }
}

# Retrieve configuration parameters from SSM Parameter Store

data "aws_ssm_parameter" "vpc_id" {
  name = "/arcgis/${var.site_id}/vpc/id"
}

data "aws_ssm_parameter" "hosted_zone_id" {
  name = "/arcgis/${var.site_id}/vpc/hosted-zone-id"
}

data "aws_ssm_parameter" "fileserver_ami" {
  name = "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver"
}

data "aws_ssm_parameter" "ami" {
  name = "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}"
}

data "aws_ssm_parameter" "public_subnets" {
  count = local.default_subnets_count
  name  = "/arcgis/${var.site_id}/vpc/public-subnet-${count.index + 1}"
}

data "aws_ssm_parameter" "private_subnets" {
  count = local.default_subnets_count
  name  = "/arcgis/${var.site_id}/vpc/private-subnet-${count.index + 1}"
}

data "aws_ssm_parameter" "instance_profile_name" {
  name = "/arcgis/${var.site_id}/iam/instance-profile-name"
}

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ami.value]
  }
}

locals {
 default_subnets_count = 2

  subnets = (length(var.subnet_ids) == 0 ? 
    [
      nonsensitive(data.aws_ssm_parameter.private_subnets[0].value),
      nonsensitive(data.aws_ssm_parameter.private_subnets[1].value)
    ] : 
    var.subnet_ids)

  arcgis_version     = try(data.aws_ami.ami.tags.ArcGISVersion, null)
}

# Create and configure the deployment's EC2 security group 
module "security_group" {
  source                = "../../modules/security_group"
  name                  = var.deployment_id
  vpc_id                = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_security_group_id = aws_security_group.arcgis_alb.id
  alb_ports             = [80, 443, 6443]
}

resource "aws_ssm_parameter" "alb_security_group_id" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group Id"
}

# Create fileserver EC2 instance
resource "aws_instance" "fileserver" {
  ami                    = data.aws_ssm_parameter.fileserver_ami.value
  subnet_id              = local.subnets[0]
  vpc_security_group_ids = [module.security_group.id]
  instance_type          = var.fileserver_instance_type
  key_name               = var.key_name
  iam_instance_profile   = nonsensitive(data.aws_ssm_parameter.instance_profile_name.value)
  monitoring             = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.fileserver_volume_size
    encrypted   = true
    iops        = 3000
    throughput  = 125
  }

  tags = {
    Name              = "${var.site_id}/${var.deployment_id}/fileserver"
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

# Create primary EC2 instance
resource "aws_instance" "primary" {
  ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)
  subnet_id              = local.subnets[0]
  vpc_security_group_ids = [module.security_group.id]
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = nonsensitive(data.aws_ssm_parameter.instance_profile_name.value)
  monitoring             = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    iops        = 3000
    throughput  = 125
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
  ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)
  # Distribute node instances in different subnets starting from the second subnet.
  subnet_id              = local.subnets[(count.index + 1) % length(local.subnets)]
  vpc_security_group_ids = [module.security_group.id]
  instance_type          = var.instance_type
  key_name               = var.key_name
  iam_instance_profile   = nonsensitive(data.aws_ssm_parameter.instance_profile_name.value)
  monitoring             = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
    iops        = 3000
    throughput  = 125
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

resource "aws_route53_record" "fileserver" {
  zone_id = data.aws_ssm_parameter.hosted_zone_id.value
  name    = "fileserver.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.fileserver.private_ip]
}

resource "aws_route53_record" "primary" {
  zone_id = data.aws_ssm_parameter.hosted_zone_id.value
  name    = "primary.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.primary.private_ip]
}

module "cw_agent" {
  source        = "../../modules/cw_agent"
  platform      = "windows"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  depends_on = [
    aws_instance.fileserver,
    aws_instance.primary,
    aws_instance.nodes
  ]
}

module "dashboard" {
  source        = "../../modules/dashboard"
  platform      = "windows"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  alb_arn       = aws_lb.alb.arn
  log_group_name = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}
