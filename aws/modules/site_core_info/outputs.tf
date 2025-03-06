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

output "vpc_id" {
  description = "VPC Id of ArcGIS Enterprise site"
  value       = data.aws_ssm_parameter.vpc_id.value
}

output "public_subnets" {
  description = "Public subnets"
  value       = jsondecode(data.aws_ssm_parameter.subnets.value).public
}

output "private_subnets" {
  description = "Private subnets"
  value       = jsondecode(data.aws_ssm_parameter.subnets.value).private
}

output "internal_subnets" {
  description = "Internal subnets"
  value       = jsondecode(data.aws_ssm_parameter.subnets.value).internal
}

output "instance_profile_name" {
  description = "Name of IAM instance profile"
  value       = data.aws_ssm_parameter.instance_profile_name.value
}

output "hosted_zone_id" {
  description = "Private hosted zone Id"
  value       = data.aws_ssm_parameter.hosted_zone_id.value
}

output "s3_repository" {
  description = "S3 repository"
  value       = data.aws_ssm_parameter.s3_repository.value
}

output "s3_backup" {
  description = "S3 backup"
  value       = data.aws_ssm_parameter.s3_backup.value
}

output "s3_logs" {
  description = "S3 logs"
  value       = data.aws_ssm_parameter.s3_logs.value
}

output "s3_region" {
  description = "S3 region"
  value       = data.aws_ssm_parameter.s3_region.value
}

