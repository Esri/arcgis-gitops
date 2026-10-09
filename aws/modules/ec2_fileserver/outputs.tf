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

output "instance_arn" {
  description = "ARN of the file-server EC2 instance"
  value       = local.instance_arn
}

output "instance_id" {
  description = "ID of the file-server EC2 instance"
  value       = local.instance_id
}

output "data_disk_association_id" {
  description = "ID of the owned file-server data-disk initialization association"
  value       = local.create_fileserver ? aws_ssm_association.initialize_data_disk[0].association_id : null
}

output "security_group_id" {
  description = "ID of the dedicated file-server security group"
  value       = local.security_group_id
}

output "private_dns" {
  description = "Private DNS name of the file-server VM"
  value       = local.private_dns
}