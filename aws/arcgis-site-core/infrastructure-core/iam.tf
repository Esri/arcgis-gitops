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

# IAM role of the site's SSM managed EC2 instances
resource "aws_iam_role" "arcgis_enterprise_role" {
  name_prefix = "ArcGISEnterpriseRole"
  description = "Permissions required for SSM managed instances and ArcGIS Enterprise apps"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ec2.amazonaws.com", "ssm.amazonaws.com"]
        }
      }
    ]
  })

  tags = {
    Name = "${var.site_id}/role"
  }
}

# IAM role policy attachments
resource "aws_iam_role_policy_attachment" "policies" {
  count      = length(var.iam_role_policies)
  role       = aws_iam_role.arcgis_enterprise_role.name
  policy_arn = var.iam_role_policies[count.index]
}

# IAM instance profile of the site's SSM managed EC2 instances
resource "aws_iam_instance_profile" "arcgis_enterprise_profile" {
  name_prefix = var.site_id
  role        = aws_iam_role.arcgis_enterprise_role.name
}

resource "aws_iam_role" "backup_role" {
  name_prefix = "ArcGISEnterpriseBackupRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach IAM policies to the backup role
resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:${local.arn_identifier}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "s3_backup" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:${local.arn_identifier}:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:${local.arn_identifier}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_iam_role_policy_attachment" "s3_restore" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:${local.arn_identifier}:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
}
