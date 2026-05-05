# Copyright 2025 Esri
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

output "public_ip_address" {
  description = "Frontend public IP address of the Application Gateway"
  value       = azurerm_public_ip.ingress.ip_address
}

output "private_ip_address" {
  description = "Private IP address of the Application Gateway"
  value       = var.ingress_private_ip
}

output "backend_address_pools" {
  description = "JSON-encoded map of backend address pool names to their IDs"
  value       = local.backend_address_pools
}
