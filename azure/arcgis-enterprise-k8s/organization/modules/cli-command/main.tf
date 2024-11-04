/**
 * # Terraform module cli-command
 * 
 * The module executes an Enterprise Admin CLI command in a Kubernetes pod.
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
 
resource "null_resource" "kubectl_exec" {
  triggers = {
    always_run = "${timestamp()}"
  }
      
  provisioner "local-exec" {
    command = "kubectl exec ${var.admin_cli_pod} --namespace=${var.namespace} -- ${join(" ", [for cmd in var.command : "\"${cmd}\""])}"
  }
}
