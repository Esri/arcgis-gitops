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
    key = "terraform/arcgis/enterprise-base-windows/infrastructure.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
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

data "aws_ssm_parameter" "alb_security_group_id" {
  name = "/arcgis/${var.enterprise_id}/${var.ingress_id}/alb/security-group-id"
}

data "aws_ssm_parameter" "primary_ami" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary"
}

data "aws_ssm_parameter" "standby_ami" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/standby"
}

data "aws_ami" "ami" {
  filter {
    name   = "image-id"
    values = [nonsensitive(data.aws_ssm_parameter.primary_ami.value)]
  }
}

locals {
  data_disk_mappings = {
    for role, image in data.aws_ami.application :
    role => one([for mapping in image.block_device_mappings : mapping if mapping.device_name == "/dev/sdf"])
  }
  namespace      = "${var.enterprise_id}${random_id.unique_name_suffix.hex}"
  primary_subnet = length(var.subnet_ids) < 2 ? module.enterprise_core_info.private_subnets[0] : var.subnet_ids[0]
  standby_subnet = length(var.subnet_ids) < 2 ? module.enterprise_core_info.private_subnets[1] : var.subnet_ids[1]
  # Get values of ArcGISTemplateId and ArcGISVersion tags from the AMI to copy them to the EC2 instances.
  arcgis_template_id = "arcgis-enterprise-base"
  arcgis_version     = try(data.aws_ami.ami.tags.ArcGISVersion, null)
}

data "aws_ami" "application" {
  for_each = var.is_ha ? {
    primary = nonsensitive(data.aws_ssm_parameter.primary_ami.value)
    standby = nonsensitive(data.aws_ssm_parameter.standby_ami.value)
  } : { primary = nonsensitive(data.aws_ssm_parameter.primary_ami.value) }
  filter {
    name   = "image-id"
    values = [each.value]
  }
}

resource "random_id" "unique_name_suffix" {
  keepers = {
    enterprise_id = var.enterprise_id
    deployment_id = var.deployment_id
  }

  byte_length = 8
}

resource "aws_ssm_parameter" "namespace" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/namespace"
  type        = "String"
  value       = local.namespace
  description = "Persistent deployment namespace for resource names and fileserver subfolders"
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
  alb_security_group_id = nonsensitive(data.aws_ssm_parameter.alb_security_group_id.value)
  alb_ports             = [80, 443, 6443, 7443]
}

resource "aws_ssm_parameter" "security_group_id" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/security-group-id"
  type        = "String"
  value       = module.security_group.id
  description = "Deployment security group ID"
}

resource "aws_network_interface" "primary" {
  subnet_id       = local.primary_subnet
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
    volume_type = var.os_disk_type
    volume_size = var.os_disk_size
    encrypted   = true
    iops        = var.os_disk_iops
    throughput  = var.os_disk_throughput
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    snapshot_id           = try(local.data_disk_mappings.primary.ebs.snapshot_id, null)
    volume_type           = var.data_disk_type
    volume_size           = var.data_disk_size
    iops                  = var.data_disk_iops
    throughput            = var.data_disk_type == "gp3" ? var.data_disk_throughput : null
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    precondition {
      condition     = try(length(local.data_disk_mappings.primary.ebs.snapshot_id) > 0 && tonumber(local.data_disk_mappings.primary.ebs.volume_size) <= var.data_disk_size, false)
      error_message = "Primary AMI must contain a /dev/sdf data snapshot that fits data_disk_size. Rebuild the image; blank replacement and shrink are prohibited."
    }
  }

  user_data = <<-EOF
  <powershell>
  ${file("${path.module}/scripts/repair_data_disk_permissions.ps1")}
  </powershell>
  EOF

  user_data_replace_on_change = false

  tags = {
    Name              = "${var.enterprise_id}/${var.deployment_id}/primary"
    ArcGISTemplateId  = local.arcgis_template_id
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "primary"
  }

  volume_tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/primary"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISMachineRole  = "primary"
  }

  depends_on = [module.ec2_fileserver]
}

module "ec2_fileserver" {
  source                       = "../../modules/ec2_fileserver"
  enterprise_id                = var.enterprise_id
  deployment_id                = var.deployment_id
  instance_type                = var.fileserver_instance_type
  key_name                     = var.key_name
  iam_instance_profile         = module.enterprise_core_info.instance_profile_name
  subnet_id                    = local.primary_subnet
  vpc_id                       = module.enterprise_core_info.vpc_id
  referenced_security_group_id = module.security_group.id
  hosted_zone_id               = module.enterprise_core_info.hosted_zone_id
  arcgis_template_id           = local.arcgis_template_id
  arcgis_version               = local.arcgis_version
  data_volume_size             = var.fileserver_data_disk_size
  data_volume_type             = var.fileserver_data_disk_type
  data_volume_iops             = var.fileserver_data_disk_iops
  data_volume_throughput       = var.fileserver_data_disk_throughput
  os_disk_size                 = var.os_disk_size
  os_disk_type                 = var.os_disk_type
  os_disk_iops                 = var.os_disk_iops
  os_disk_throughput           = var.os_disk_throughput
}

resource "aws_network_interface" "standby" {
  count           = var.is_ha ? 1 : 0
  subnet_id       = local.standby_subnet
  security_groups = [module.security_group.id]

  tags = {
    Name = "${var.enterprise_id}/${var.deployment_id}/standby"
  }
}

# Create standby EC2 instance
resource "aws_instance" "standby" {
  count                = var.is_ha ? 1 : 0
  ami                  = nonsensitive(data.aws_ssm_parameter.standby_ami.value)
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = module.enterprise_core_info.instance_profile_name
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.standby[0].id
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = var.os_disk_type
    volume_size = var.os_disk_size
    encrypted   = true
    iops        = var.os_disk_iops
    throughput  = var.os_disk_throughput
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    snapshot_id           = try(local.data_disk_mappings.standby.ebs.snapshot_id, null)
    volume_type           = var.data_disk_type
    volume_size           = var.data_disk_size
    iops                  = var.data_disk_iops
    throughput            = var.data_disk_type == "gp3" ? var.data_disk_throughput : null
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    precondition {
      condition     = try(length(local.data_disk_mappings.standby.ebs.snapshot_id) > 0 && tonumber(local.data_disk_mappings.standby.ebs.volume_size) <= var.data_disk_size, false)
      error_message = "Standby AMI must contain a /dev/sdf data snapshot that fits data_disk_size. Rebuild the image; blank replacement and shrink are prohibited."
    }
  }

  user_data = <<-EOF
  <powershell>
  ${file("${path.module}/scripts/repair_data_disk_permissions.ps1")}
  </powershell>
  EOF

  user_data_replace_on_change = false

  tags = {
    Name              = "${var.enterprise_id}/${var.deployment_id}/standby"
    ArcGISTemplateId  = local.arcgis_template_id
    ArcGISVersion     = local.arcgis_version
    ArcGISMachineRole = "standby"
  }

  volume_tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/standby"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISMachineRole  = "standby"
  }

  depends_on = [module.ec2_fileserver]
}

resource "aws_route53_record" "primary" {
  zone_id = module.enterprise_core_info.hosted_zone_id
  name    = "primary.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.primary.private_ip]
}

resource "aws_route53_record" "standby" {
  count   = var.is_ha ? 1 : 0
  zone_id = module.enterprise_core_info.hosted_zone_id
  name    = "standby.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.standby[0].private_ip]
}

# Create S3 bucket for the portal content
resource "aws_s3_bucket" "portal_content" {
  bucket        = "${local.namespace}-portal-content"
  force_destroy = true

  tags = {
    ArcGISRole = "portal-content"
  }
}

# Enable S3 bucket versioning required by AWS Backup
resource "aws_s3_bucket_versioning" "portal_content" {
  bucket = aws_s3_bucket.portal_content.id
  versioning_configuration {
    status = "Enabled"
  }
}

# AWS Backup S3 restores require the ability to set object ACLs.
resource "aws_s3_bucket_ownership_controls" "portal_content" {
  bucket = aws_s3_bucket.portal_content.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_ssm_parameter" "portal_content_s3_bucket" {
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/content-s3-bucket"
  type        = "String"
  value       = aws_s3_bucket.portal_content.bucket
  description = "Portal for ArcGIS content store S3 bucket"
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

module "cw_agent" {
  source        = "../../modules/cw_agent"
  platform      = "windows"
  enterprise_id = var.enterprise_id
  deployment_id = var.deployment_id
  depends_on = [
    aws_instance.primary,
    aws_instance.standby,
    module.ec2_fileserver
  ]
}

module "dashboard" {
  separate_disk_metrics = true
  source                = "../../modules/dashboard"
  platform              = "windows"
  enterprise_id         = var.enterprise_id
  deployment_id         = var.deployment_id
  log_group_name        = module.cw_agent.log_group_name
  depends_on = [
    module.cw_agent
  ]
}
