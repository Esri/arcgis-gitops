/*
 * # Terraform module az_copy_files
 *
 * Terraform module az_copy_files copies files from local file system, public URLs, and, My Esri, and ArcGIS patch repositories to Azure Blob Storage.
 *
 * The module uses az_copy_files.py script to copy files defined in a JSON index file to an Azure Blob Storage container.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured
 */

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

resource "null_resource" "az_copy_files" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    command = "python -m az_copy_files -f ${var.index_file} -a ${var.storage_account_blob_endpoint} -c ${var.container_name}"
  }
}
