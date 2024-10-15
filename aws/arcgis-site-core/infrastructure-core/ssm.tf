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

# Add parameters to SSM Parameter Store

resource "aws_ssm_parameter" "vpc_id" {
  name        = "/arcgis/${var.site_id}/vpc/id"
  type        = "String"
  value       = aws_vpc.vpc.id
  description = "VPC Id of ArcGIS Enterprise site '${var.site_id}'"
}

resource "aws_ssm_parameter" "hosted_zone_id" {
  name        = "/arcgis/${var.site_id}/vpc/hosted-zone-id"
  type        = "String"
  value       = aws_route53_zone.private.id
  description = "Private hosted zone Id of ArcGIS Enterprise site '${var.site_id}'"
}

resource "aws_ssm_parameter" "internal_subnets" {
  count       = length(aws_subnet.internal_subnets)
  name        = "/arcgis/${var.site_id}/vpc/internal-subnet/${count.index + 1}"
  type        = "String"
  value       = aws_subnet.internal_subnets[count.index].id
  description = "Id of internal VPC subnet ${count.index + 1}"
}

resource "aws_ssm_parameter" "private_subnets" {
  count       = length(aws_subnet.private_subnets)
  name        = "/arcgis/${var.site_id}/vpc/private-subnet/${count.index + 1}"
  type        = "String"
  value       = aws_subnet.private_subnets[count.index].id
  description = "Id of private VPC subnet ${count.index + 1}"
}

resource "aws_ssm_parameter" "public_subnets" {
  count       = length(aws_subnet.public_subnets)
  name        = "/arcgis/${var.site_id}/vpc/public-subnet/${count.index + 1}"
  type        = "String"
  value       = aws_subnet.public_subnets[count.index].id
  description = "Id of public VPC subnet ${count.index + 1}"
}

resource "aws_ssm_parameter" "instance_profile_name" {
  name        = "/arcgis/${var.site_id}/iam/instance-profile-name"
  type        = "String"
  value       = aws_iam_instance_profile.arcgis_enterprise_profile.name
  description = "Name of IAM instance profile"
}

resource "aws_ssm_parameter" "s3_repository" {
  name        = "/arcgis/${var.site_id}/s3/repository"
  type        = "String"
  value       = aws_s3_bucket.repository.bucket
  description = "S3 bucket of private repository"
}

resource "aws_ssm_parameter" "s3_backup" {
  name        = "/arcgis/${var.site_id}/s3/backup"
  type        = "String"
  value       = aws_s3_bucket.backup.bucket
  description = "S3 bucket used by deployments to store backup data"
}

resource "aws_ssm_parameter" "s3_logs" {
  name        = "/arcgis/${var.site_id}/s3/logs"
  type        = "String"
  value       = aws_s3_bucket.logs.bucket
  description = "S3 bucket used by deployments to store logs"
}

resource "aws_ssm_parameter" "s3_region" {
  name        = "/arcgis/${var.site_id}/s3/region"
  type        = "String"
  value       = data.aws_region.current.id
  description = "S3 buckets region code"
}

# AMIs

resource "aws_ssm_parameter" "images_parameters" {
  for_each = data.aws_ami.os_image
  name  = "/arcgis/${var.site_id}/images/${each.key}"
  type  = "String"
  value = each.value.id
  description = each.value.description
}


