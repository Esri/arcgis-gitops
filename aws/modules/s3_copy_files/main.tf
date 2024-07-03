/*
 * # Terraform module s3_copy_files
 * 
 * Terraform module s3_copy_files copies files from local file system, public URLs, and, My Esri, and ArcGIS patch repositories to S3 bucket.
 *
 * The module uses s3_copy_files.py script to copy files defined in a JSON index file to an S3 bucket.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 * * My Esri user name and password must be specified either by environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or using the input variables.
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

locals {
  username_param = var.arcgis_online_username == null ? "" : "-u ${var.arcgis_online_username}"
  password_param = var.arcgis_online_password == null ? "" : "-p ${var.arcgis_online_password}"
}

resource "null_resource" "s3_copy_files" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    command = "python -m s3_copy_files -f ${var.index_file} -b ${var.bucket_name} ${local.username_param} ${local.password_param}"
  }
}
