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
    key = "terraform/arcgis-enterprise/arcgis-server/restore.tfstate"
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

module "backup_enterprise_core_info" {
  source = "../../modules/enterprise_core_info"
  enterprise_id = var.backup_enterprise_id
}

data "aws_region" "current" {}

# Restore ArcGIS Server configurtion from backup
module "arcgis_server_restore" {
  source         = "../../modules/ansible_playbook"
  enterprise_id        = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  playbook       = "arcgis.server.s3_restore"
  external_vars  = {
    server_url = "https://localhost:6443/arcgis"
    admin_username = var.admin_username
    admin_password = var.admin_password
    install_dir = "/opt"
    run_as_user = var.run_as_user
    s3_bucket = module.backup_enterprise_core_info.s3_backup
    s3_region = module.backup_enterprise_core_info.s3_region
    s3_prefix = var.s3_prefix
  }
}
