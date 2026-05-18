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

output "aznfs_network_path" {
  description = "The network path to access the NFS file share, stored as a secret in Key Vault."
  value       = local.aznfs_network_path
}

output "storage_account_id" {
  description = "The ID of the storage account associated with the NFS file share."
  value       = var.fileserver_deployment_id == null ? azurerm_storage_account.file_store[0].id : null
}
