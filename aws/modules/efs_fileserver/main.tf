# Copyright 2026 Esri
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

data "aws_ssm_parameter" "file_system_id" {
  count = var.fileserver_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/file-system-id"
}

data "aws_ssm_parameter" "security_group_id" {
  count = var.fileserver_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/security-group-id"
}

locals {
  file_system_id = (var.fileserver_deployment_id != null ?
    nonsensitive(data.aws_ssm_parameter.file_system_id[0].value) :
    aws_efs_file_system.fileserver[0].id)
  
  file_system_security_group_id = (var.fileserver_deployment_id != null ?
    nonsensitive(data.aws_ssm_parameter.security_group_id[0].value) :
    aws_security_group.file_system_sg[0].id)
}

# Create EFS file system for the deployment's file server
resource "aws_efs_file_system" "fileserver" {
  count     = var.fileserver_deployment_id == null ? 1 : 0
  encrypted = true

  tags = {
    Name       = "${var.enterprise_id}/${var.deployment_id}/fileserver"
    ArcGISRole = "fileserver"
  }
}

resource "aws_ssm_parameter" "file_system_id" {
  count       = var.fileserver_deployment_id == null ? 1 : 0
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/file-system-id"
  type        = "String"
  value       = aws_efs_file_system.fileserver[0].id
  description = "Deployment EFS file system ID"
}

resource "aws_security_group" "file_system_sg" {
  count       = var.fileserver_deployment_id == null ? 1 : 0
  name        = "${var.enterprise_id}-${var.deployment_id}-efs"
  description = "EFS Mount Target Security Group"
  vpc_id      = var.vpc_id
}

resource "aws_ssm_parameter" "file_system_sg" {
  count       = var.fileserver_deployment_id == null ? 1 : 0
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/security-group-id"
  description = "Deployment EFS file system security group ID"
  type        = "String"
  value       = aws_security_group.file_system_sg[0].id
}

resource "aws_vpc_security_group_ingress_rule" "allow_nfs_from_ec2" {
  security_group_id            = local.file_system_security_group_id
  description                  = "Allow NFS traffic from EC2 instances"
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.referenced_security_group_id
}

# Create EFS mount targets for the EFS file system in the deployment's subnets.
resource "aws_efs_mount_target" "fileserver" {
  count          = var.fileserver_deployment_id == null ? length(var.subnet_ids) : 0
  file_system_id = aws_efs_file_system.fileserver[0].id
  subnet_id      = var.subnet_ids[count.index]
  security_groups = [
    aws_security_group.file_system_sg[0].id
  ]
}
