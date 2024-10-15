/*
 * # Terraform module site_core_info
 * 
 * Terraform module site_core_info retrieves names and Ids of core AWS resources
 * created by infrastructure-core module from AWS Systems Manager parameters and
 * returns them as output values. 
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

# Retrieve configuration parameters from SSM Parameter Store

data "aws_ssm_parameter" "vpc_id" {
  name = "/arcgis/${var.site_id}/vpc/id"
}

data "aws_ssm_parameter" "hosted_zone_id" {
  name = "/arcgis/${var.site_id}/vpc/hosted-zone-id"
}

data "aws_ssm_parameters_by_path" "public_subnets" {
  path = "/arcgis/${var.site_id}/vpc/public-subnet/"
}

data "aws_ssm_parameters_by_path" "private_subnets" {
  path  = "/arcgis/${var.site_id}/vpc/private-subnet/"
}

data "aws_ssm_parameters_by_path" "internal_subnets" {
  path  = "/arcgis/${var.site_id}/vpc/internal-subnet/"
}

data "aws_ssm_parameter" "instance_profile_name" {
  name = "/arcgis/${var.site_id}/iam/instance-profile-name"
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.site_id}/s3/repository"
}

data "aws_ssm_parameter" "s3_backup" {
  name = "/arcgis/${var.site_id}/s3/backup"
}

data "aws_ssm_parameter" "s3_logs" {
  name = "/arcgis/${var.site_id}/s3/logs"
}

data "aws_ssm_parameter" "s3_region" {
  name        = "/arcgis/${var.site_id}/s3/region"
}

