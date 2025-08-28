/*
 * # Terraform module backup
 * 
 * Terraform module configures system-level backups in AWS Backup service of 
 * the cloud configuration stores of different server roles.
 *
 * ## SSM Parameters
 *
 * The module reads the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/backup/plan-id | Backup plan ID for the deployment | 
 * | /arcgis/${var.site_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |
 */

# Copyright 2025 Esri
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

# The script enables system-level backups of ArcGIS Server config store AWS resources
# using AWS Backup service.

data "aws_region" "current" {}

# Retrieve the S3 bucket and DynamoDB table names for the configstore namespace from 
# ArcGISConfigStores DynamoDB table
data "aws_ssm_parameter" "backup_role_arn" {
  name = "/arcgis/${var.site_id}/iam/backup-role-arn"
}

data "aws_ssm_parameter" "backup_plan_id" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/backup/plan-id"
}

data "aws_dynamodb_table_item" "config_store" {
  table_name = "ArcGISConfigStores"
  key = jsonencode({
    Namespace = {
      S = "${var.site_id}-${var.deployment_id}"
    }
  })
}

data "aws_s3_bucket" "config_store_bucket" {
  bucket = jsondecode(data.aws_dynamodb_table_item.config_store.item).S3BucketName.S
}

data "aws_dynamodb_table" "config_store_table" {
  name = jsondecode(data.aws_dynamodb_table_item.config_store.item).DBTableName.S
}

# Tag the config store S3 bucket with ArcGIS site ID, deployment ID, and role.
# Enable S3 bucket versioning required by AWS Backup.
resource "null_resource" "tag_s3_bucket" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.region
    }

    command = "python -m tag_s3_bucket -b ${data.aws_s3_bucket.config_store_bucket.bucket} -s ${var.site_id} -d ${var.deployment_id} -m config-store"
  }
}

resource "aws_dynamodb_tag" "config_store_table" {
  for_each = {
    "ArcGISSiteId" : var.site_id,
    "ArcGISDeploymentId" : var.deployment_id,
    "ArcGISRole" : "config-store"
  }

  resource_arn = data.aws_dynamodb_table.config_store_table.arn
  key         = each.key
  value       = each.value
}

# Add all the deployment's config store S3 bucket and DynamoDB table to 
# the backup plan resources selection.
resource "aws_backup_selection" "application" {
  iam_role_arn = nonsensitive(data.aws_ssm_parameter.backup_role_arn.value)
  name         = "${var.site_id}-${var.deployment_id}-application"
  plan_id      = nonsensitive(data.aws_ssm_parameter.backup_plan_id.value)

  resources = [
    data.aws_s3_bucket.config_store_bucket.arn,
    data.aws_dynamodb_table.config_store_table.arn
  ]
}
