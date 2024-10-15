/*
 * # Terraform module bootstrap
 * 
 * Terraform module installs or upgrades Chef client and Chef Cookbooks for ArcGIS on EC2 instances.
 *
 * The module uses ssm_bootstrap.py script to run {var.site-id}-bootstrap SSM command on the deployment's EC2 instances in specific roles.
 *
 * ## Requirements
 *
 * The S3 bucket for the SSM command output is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
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
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "chef_client_url" {
  name  = "/arcgis/${var.site_id}/chef-client-url/${var.os}"
}

data "aws_ssm_parameter" "chef_cookbooks_url" {
  name  = "/arcgis/${var.site_id}/cookbooks-url"
}

locals {
  chef_client_url     = var.chef_client_url != null ? var.chef_client_url : data.aws_ssm_parameter.chef_client_url.value
  chef_cookbooks_url  = var.chef_cookbooks_url != null ? var.chef_cookbooks_url : data.aws_ssm_parameter.chef_cookbooks_url.value
}

resource "null_resource" "bootstrap" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.name
    }

    command = "python -m ssm_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -c ${local.chef_client_url} -k ${local.chef_cookbooks_url} -b ${var.output_s3_bucket}"
  }
}
