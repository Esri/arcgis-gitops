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

output "file_system_id" {
  description = "EFS file system ID for the deployment's file server"
  value       = local.file_system_id
}

output "file_system_arn" {
  description = "EFS file system ARN"
  value = var.fileserver_deployment_id == null ? aws_efs_file_system.fileserver[0].arn : null
}

output "security_group_id" {
  description = "Security group ID for the deployment's file server EFS file system"
  value       = local.file_system_security_group_id
}