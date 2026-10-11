# Copyright 2024-2026 Esri
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

output "security_group_id" {
  description = "EC2 security group ID"
  value       = module.security_group.id
}

output "fileserver_security_group_id" {
  description = "Dedicated Windows file-server security group ID"
  value       = module.ec2_fileserver.security_group_id
}

output "fileserver_private_dns" {
  description = "Private DNS name of the dedicated Windows file-server VM"
  value       = module.ec2_fileserver.private_dns
}

output "fileserver_data_disk_association_id" {
  description = "SSM association to verify after infrastructure apply"
  value       = module.ec2_fileserver.data_disk_association_id
}

output "deployment_url" {
  description = "Portal for ArcGIS URL of the deployment"
  value       = "https://${nonsensitive(data.aws_ssm_parameter.alb_ingress_fqdn.value)}/${local.portal_web_context}"
}
