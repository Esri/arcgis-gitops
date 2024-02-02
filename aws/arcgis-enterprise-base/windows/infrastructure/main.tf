/**
 * # Infrastructure Terraform Module for base ArcGIS Enterprise on Windows
 *
 * The Terraform module creates AWS resources for highly available base ArcGIS Enterprise deployment on Windows platform.
 *
 * ![Base ArcGIS Enterprise on Windows / Infrastructure](images/arcgis-enterprise-base-windows-infrastructure.png "Base ArcGIS Enterprise on Windows / Infrastructure")
 *
 * The module launches three SSM managed EC2 instances in the private or isolated VPC subnets created by infrastructure-core Terraform module. 
 * The primary and standby instances are launched from image retrieved from '/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/main' SSM parameter. 
 * The fileserver instance is launched from image retrieved from '/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver' SSM parameter. 
 * The images must be created by the Packer Template for Base ArcGIS Enterprise on Windows. 
 *
 * Records in the VPC Route53 private hosted zone are created for the EC2 instances to make the instancess addressable using permanent DNS names like `fileserver.arcgis-enterprise-base.arcgis-enterprise.internal`.
 * 
 * > Note that the EC2 instance will be terminated and recreated if the infrastructure terraform module is applied again after the SSM parameter value was modified by a new image build.
 *
 * The module creates:
 * * An Application Load Balancer with HTTPS listeners for ports 80, 443, 6443, and 7443, as well as target groups for those listeners that target the EC2 instances .
 * * An SNS topic and CloudWatch alarms that monitor the target groups and post to the SNS topic if the number of unhelathy instances in nonzero. 
 * * A CloudWatch log group and configures CloudWatch agent on the EC2 instances to send the system and Chef run logs to the log group as well as monitor memory and disk utilization on the EC2 instances. 
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
 * Before creating the infrastructure, an SSL certificate for the base ArcGIS Enterprise deployment domain name 
 * must be imported into or issued by AWS Certificate Manager service in the AWS account. The certificate's
 * ARN specified by "ssl_certificate_arn" input variable will be used to configure HTTPS listeners of the load balancer.
 * 
 * After creating the infrastructure, the domain name must be pointed to the DNS name of Application Load Balancer 
 * exported by "alb_dns_name" output value of the module.
 *
 * ## Troubleshooting
 *
 * Use Session Manager connection in AWS Console for SSH access to the EC2 instances.
 *
 * The SSM commands output stored in the logs S3 bucket is copied in the Trerraform stdout.
 * 
 * ## SSM Parameters
 *
 * The module uses the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name |
 * | /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver | Id of the fileserver AMI |
 * | /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/main | Id of the main AMI |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/vpc/${var.subnet_type}-subnet-1 | VPC subnet 1 Id |
 * | /arcgis/${var.site_id}/vpc/${var.subnet_type}-subnet-2 | VPC subnet 2 Id |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | VPC hosted zone Id |
 * | /arcgis/${var.site_id}/vpc/id | VPC Id |
 */

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
  name = "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/main"
}

data "aws_ssm_parameter" "primary_subnet" {
  name = "/arcgis/${var.site_id}/vpc/${var.subnet_type}-subnet-1"
}

data "aws_ssm_parameter" "standby_subnet" {
  name = "/arcgis/${var.site_id}/vpc/${var.subnet_type}-subnet-2"
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
  primary_subnet = nonsensitive(data.aws_ssm_parameter.primary_subnet.value)
  standby_subnet = nonsensitive(data.aws_ssm_parameter.standby_subnet.value)
  # Get values of ArcGISTemplateId and ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_template_id = "arcgis-enterprise-base"
  arcgis_version     = try(data.aws_ami.ami.tags.ArcGISVersion, null)
}

# Create and configure the deployment's EC2 security group 
module "security_group" {
  source                = "../../../modules/security_group"
  name                  = var.deployment_id
  vpc_id                = nonsensitive(data.aws_ssm_parameter.vpc_id.value)
  alb_security_group_id = aws_security_group.arcgis_alb.id
  alb_ports             = [80, 443, 6443, 7443]
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
  subnet_id              = local.primary_subnet
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

# Create primary EC2 instance
resource "aws_instance" "primary" {
  ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)
  subnet_id              = local.primary_subnet
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

# Create standby EC2 instance
resource "aws_instance" "standby" {
  ami                    = nonsensitive(data.aws_ssm_parameter.ami.value)
  subnet_id              = local.standby_subnet
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

resource "aws_route53_record" "standby" {
  zone_id = data.aws_ssm_parameter.hosted_zone_id.value
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

module "cw_agent" {
  source        = "../../../modules/cw_agent"
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
  source        = "../../../modules/dashboard"
  name          = var.deployment_id
  site_id       = var.site_id
  deployment_id = var.deployment_id
  alb_arn       = aws_lb.alb.arn
  target_group_arns = [
    module.portal_https_alb_target.arn,
    module.server_https_alb_target.arn,
    module.private_portal_https_alb_target.arn,
    module.private_server_https_alb_target.arn
  ]
  log_group_name = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}
