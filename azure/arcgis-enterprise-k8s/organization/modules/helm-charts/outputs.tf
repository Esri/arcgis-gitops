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

# output "configure_yaml_path" {
#   description = "Path to the generated configure.yaml file for ArcGIS Enterprise on Kubernetes"
#   value       = "${var.install_dir}/${local.helm_charts_version}/configure.yaml"
#   depends_on = [ 
#     null_resource.rename_files 
#   ]
# }

output "configure_yaml_content" {
  description = "Content of the configure.yaml file of the Helm charts"
  value       = data.local_file.configure_yaml.content
}

output "helm_charts_version" {
  description = "Version of Helm Charts for ArcGIS Enterprise on Kubernetes"
  value       = local.helm_charts_version
}

output "helm_charts_path" {
  description = "Path to the Helm Charts for ArcGIS Enterprise on Kubernetes"
  value       = "${var.install_dir}/${local.helm_charts_version}"
}
