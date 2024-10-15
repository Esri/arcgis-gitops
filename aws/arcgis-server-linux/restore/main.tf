/**
 * # Restore Terraform Module for ArcGIS Server on Linux
 *
 * The Terraform module retrieves the last a backup from S3 bucket and restores ArcGIS Server deployment from the backup.
 *
 * The module runs 'restore' admin utility on the primary EC2 instance of the deployment.
 *
 * ## Requirements
 *
 * The ArcGIS Server must be configured on the deployment by application terraform module for ArcGIS Server on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Ansible 2.16 or later must be installed
 * * arcgis.common and arcgis.server Ansible collections must be installed
 * * AWS credentials must be configured
 *
 * The module retrieves the backup S3 bucket name from '/arcgis/${var.site_id}/s3/backup' SSM parameters.
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
    key = "terraform/arcgis-enterprise/arcgis-server/restore.tfstate"
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
  region = var.aws_region
  
  default_tags {
    tags = {
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }
}

module "site_core_info" {
  source = "../../modules/site_core_info"
  site_id = var.site_id
}

data "aws_region" "current" {}

# Restore ArcGIS Server configurtion from backup
module "arcgis_server_restore" {
  source         = "../../modules/ansible_playbook"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  playbook       = "arcgis.server.s3_restore"
  external_vars  = {
    server_url = "https://localhost:6443/arcgis"
    admin_username = var.admin_username
    admin_password = var.admin_password
    install_dir = "/opt"
    run_as_user = var.run_as_user
    s3_bucket = module.site_core_info.s3_backup
    s3_region = module.site_core_info.s3_region
    s3_prefix = var.s3_prefix
  }
}
