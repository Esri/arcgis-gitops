/**
 * # Terraform module run_chef
 * 
 * Terraform module run_chef runs Cinc client in zero mode on EC2 instances in specified roles.
 * 
 * The module runs ssm_run_chef.py python script that creates a SecureString SSM parameter with Chef JSON attributes and
 * runs {var.site-id}-run-chef SSM command on the deployment's EC2 instances in specific roles.
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
 *
 *  Cinc client and Chef Cookbooks for ArcGIS must be installed on the target EC2 instances.
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

data "aws_ssm_parameter" "output_s3_bucket" {
  name  = "/arcgis/${var.site_id}/s3/logs"
}

resource "null_resource" "run_chef" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    environment = {
      JSON_ATTRIBUTES = nonsensitive(base64encode(var.json_attributes))
      AWS_DEFAULT_REGION = data.aws_region.current.name
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -j ${var.parameter_name} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)} -e ${var.execution_timeout}"
  }
}
