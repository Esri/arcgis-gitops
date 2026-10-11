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

output "vm_id" {
  description = "ID of the file-server VM"
  value       = local.vm_id
}

output "security_group_id" {
  description = "ID of the existing subnet network security group inherited by the file server, or the referenced owner's network security group"
  value       = local.security_group_id
}

output "private_dns" {
  description = "Private DNS name of the file-server VM"
  value       = local.private_dns
}