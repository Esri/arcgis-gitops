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

  managed_policy_arns = [
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonS3FullAccess",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:${local.arn_identifier}:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:${local.arn_identifier}:iam::aws:policy/AmazonElasticFileSystemClientFullAccess",
    "arn:${local.arn_identifier}:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  ]

  tags = {
    Name = "${var.site_id}/role"
  }
}

# IAM instance profile of the site's SSM managed EC2 instances
resource "aws_iam_instance_profile" "arcgis_enterprise_profile" {
  name_prefix = var.site_id
  role        = aws_iam_role.arcgis_enterprise_role.name
}
