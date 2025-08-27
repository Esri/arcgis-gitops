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

# System-level backups using AWS Backup service.

data "aws_ssm_parameter" "backup_role_arn" {
  name = "/arcgis/${var.site_id}/iam/backup-role-arn"
}

data "aws_ssm_parameter" "backup_vault_name" {
  name = "/arcgis/${var.site_id}/backup/vault-name"
}

# Create a backup plan for the deployment.
resource "aws_backup_plan" "deployment_backup" {
  name = "${var.site_id}-${var.deployment_id}"

  rule {
    rule_name         = "scheduled-deployment-backup"
    target_vault_name = nonsensitive(data.aws_ssm_parameter.backup_vault_name.value)
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention
    }
  }
}

resource "aws_ssm_parameter" "backup_plan_id" {
  name        = "/arcgis/${var.site_id}/${var.deployment_id}/backup/plan-id"
  type        = "String"
  value       = aws_backup_plan.deployment_backup.id
  description = "Backup plan ID for the deployment ${var.site_id}/${var.deployment_id}"
}

# Add all the deployment's EC2 instances, S3 buckets, and EFS file systems to 
# the backup plan resources.
resource "aws_backup_selection" "infrastructure" {
  iam_role_arn = nonsensitive(data.aws_ssm_parameter.backup_role_arn.value)
  name         = "${var.site_id}-${var.deployment_id}-infrastructure"
  plan_id      = aws_backup_plan.deployment_backup.id

  resources = var.node_count > 0 ? [
    aws_instance.primary.arn,
    aws_instance.nodes[0].arn,
    aws_efs_file_system.fileserver.arn
  ] : [
    aws_instance.primary.arn,
    aws_efs_file_system.fileserver.arn
  ]
}
