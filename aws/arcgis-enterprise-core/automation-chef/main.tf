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
    key = "arcgis-enterprise/aws/automation-chef.tfstate"
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
    }
  }
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.enterprise_id}/s3/repository"
}


# Copy Chef automation tools to S3

module "s3_copy_files" {
  source = "../../modules/s3_copy_files"
  bucket_name = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  index_file = "manifests/automation-chef-files.json"
}

# Create/update SSM documents

resource "aws_ssm_document" "install_awscli_command" {
  name          = "${var.enterprise_id}-install-awscli"
  document_type = "Command"
  content = file("${path.module}/commands/install-awscli.json")
}

resource "aws_ssm_document" "efs_mount_command" {
  name          = "${var.enterprise_id}-efs-mount"
  document_type = "Command"
  content = file("${path.module}/commands/efs-mount.json")
}

resource "aws_ssm_document" "bootstrap_command" {
  name          = "${var.enterprise_id}-bootstrap"
  document_type = "Command"
  content = replace(replace(
    file("${path.module}/commands/bootstrap.json"), 
    "{{ssm:/arcgis/arcgis-enterprise/chef-client-url/windows2022}}",
    "{{ssm:/arcgis/${var.enterprise_id}/chef-client-url/windows2022}}"),
    "{{ssm:/arcgis/arcgis-enterprise/cookbooks-url}}",
    "{{ssm:/arcgis/${var.enterprise_id}/cookbooks-url}}")
}

resource "aws_ssm_document" "run_chef_command" {
  name          = "${var.enterprise_id}-run-chef"
  document_type = "Command"
  content = replace(
    file("${path.module}/commands/run-chef.json"),
    "/chef/log_level",
    "/chef/${var.enterprise_id}/log_level")   
}

resource "aws_ssm_document" "clean_up_command" {
  name          = "${var.enterprise_id}-clean-up"
  document_type = "Command"
  content = file("${path.module}/commands/clean-up.json")
}

# Chef client

resource "aws_ssm_parameter" "chef_client_urls" {
  for_each = var.chef_client_paths
  name  = "/arcgis/${var.enterprise_id}/chef-client-url/${each.key}"
  type  = "String"
  value = nonsensitive("s3://${data.aws_ssm_parameter.s3_repository.value}/${var.chef_client_paths[each.key].path}")
  description = var.chef_client_paths[each.key].description
}

resource "aws_ssm_parameter" "chef_client_log_level" {
  name  = "/chef/${var.enterprise_id}/log_level"
  type  = "String"
  value = "info"
  description = "Chef/Cinc client log level"
}

# Chef Cookbooks

resource "aws_ssm_parameter" "arcgis_cookbooks_url" {
  name  = "/arcgis/${var.enterprise_id}/cookbooks-url"
  type  = "String"
  value = nonsensitive("s3://${data.aws_ssm_parameter.s3_repository.value}/${var.arcgis_cookbooks_path}")
  description = "Chef cookbooks for ArcGIS distribution archive S3 URL"
}
