/**
 * # Terraform module automation-chef
 *
 * The module provisions AWS resources required for ArcGIS Enterprise site configuration management 
 * using IT automation tool Chef/Cinc:
 *
 * * Copies Chef/Cinc client setups and Chef cookbooks for ArcGIS distribution archive from the URLs specified
 * in [automation-chef-files.json](manifests/automation-chef-files.json) file to the private repository S3 bucket
 * * Creates SSM documents for the ArcGIS Enterprise site
 * 
 * The S3 URLs are stored in SSM parameters:
 *
 * | SSM parameter name | Description |
 * | --- | --- |
 * | /arcgis/${var.site_id}/chef-client-url/${os} | S3 URLs of Cinc Client setup for the operating systems |
 * | /arcgis/${var.site_id}/cookbooks-url | S3 URL of Chef cookbooks for ArcGIS distribution archive |
 *
 * SSM documents created by the module:
 * 
 * | SSM document name | Description |
 * | --- | --- |
 * | ${var.site_id}-bootstrap | Installs Chef/Cinc Client and Chef Cookbooks for ArcGIS on EC2 instances |
 * | ${var.site_id}-clean-up | Deletes temporary files created by Chef runs |
 * | ${var.site_id}-install-awscli | Installs AWS CLI on EC2 instances |
 * | ${var.site_id}-efs-mount | Mounts EFS targets on EC2 instances |
 * | ${var.site_id}-run-chef | Runs Chef in solo ode with specified JSON attributes |
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the automation-chef module path (because [automation-chef-files.json](manifests/automation-chef-files.json) uses relative path to the Chef cookbooks archive)
 * * AWS credentials must be configured.
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable.
 *
 * Before using the module, the repository S3 bucket must be created by infrastructure-core terraform module.
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
      ArcGISAutomation = "arcgis-gitops"      
      ArcGISSiteId     = var.site_id
    }
  }
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.site_id}/s3/repository"
}


# Copy Chef automation tools to S3

module "s3_copy_files" {
  source = "../../modules/s3_copy_files"
  bucket_name = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  index_file = "manifests/automation-chef-files.json"
}

# Create/update SSM documents

resource "aws_ssm_document" "install_awscli_command" {
  name          = "${var.site_id}-install-awscli"
  document_type = "Command"
  content = file("${path.module}/commands/install-awscli.json")
}

resource "aws_ssm_document" "efs_mount_command" {
  name          = "${var.site_id}-efs-mount"
  document_type = "Command"
  content = file("${path.module}/commands/efs-mount.json")
}

resource "aws_ssm_document" "bootstrap_command" {
  name          = "${var.site_id}-bootstrap"
  document_type = "Command"
  content = replace(replace(
    file("${path.module}/commands/bootstrap.json"), 
    "{{ssm:/arcgis/arcgis-enterprise/chef-client-url/windows2022}}",
    "{{ssm:/arcgis/${var.site_id}/chef-client-url/windows2022}}"),
    "{{ssm:/arcgis/arcgis-enterprise/cookbooks-url}}",
    "{{ssm:/arcgis/${var.site_id}/cookbooks-url}}")
}

resource "aws_ssm_document" "run_chef_command" {
  name          = "${var.site_id}-run-chef"
  document_type = "Command"
  content = replace(
    file("${path.module}/commands/run-chef.json"),
    "/chef/log_level",
    "/chef/${var.site_id}/log_level")   
}

resource "aws_ssm_document" "clean_up_command" {
  name          = "${var.site_id}-clean-up"
  document_type = "Command"
  content = file("${path.module}/commands/clean-up.json")
}

# Chef client

resource "aws_ssm_parameter" "chef_client_urls" {
  for_each = var.chef_client_paths
  name  = "/arcgis/${var.site_id}/chef-client-url/${each.key}"
  type  = "String"
  value = nonsensitive("s3://${data.aws_ssm_parameter.s3_repository.value}/${var.chef_client_paths[each.key].path}")
  description = var.chef_client_paths[each.key].description
}

resource "aws_ssm_parameter" "chef_client_log_level" {
  name  = "/chef/${var.site_id}/log_level"
  type  = "String"
  value = "info"
  description = "Chef/Cinc client log level"
}

# Chef Cookbooks

resource "aws_ssm_parameter" "arcgis_cookbooks_url" {
  name  = "/arcgis/${var.site_id}/cookbooks-url"
  type  = "String"
  value = nonsensitive("s3://${data.aws_ssm_parameter.s3_repository.value}/${var.arcgis_cookbooks_path}")
  description = "Chef cookbooks for ArcGIS distribution archive S3 URL"
}
