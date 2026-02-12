/**
 * # Terraform module helm-charts
 * 
 * The module downloads the Helm Charts for ArcGIS Enterprise on Kubernetes tarball
 * from the repository specified in the index file, extracts the charts from the tarball 
 * into the specified installation directory, and renames the extracted directory
 * to the Helm charts version.
 *
 * The module skips the steps above if the Helm charts already exist in the installation directory.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 * 
 * * Current working directory must be the root of the "organization" module. 
 * * Python 3.9 or later must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * ArcGIS Online credentials must be set by ARCGIS_ONLINE_PASSWORD and 
 *   ARCGIS_ONLINE_USERNAME environment variables.
 */

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

data "local_file" "configure_yaml" {
  filename = local.configure_yaml_path
  
  depends_on = [
    null_resource.rename_files
  ]
}

locals {
  metadata            = jsondecode(file(var.index_file)).arcgis.repository.metadata
  helm_charts_tarball = local.metadata.helm_charts_tarball
  helm_charts_version = local.metadata.helm_charts_version
  configure_yaml_path = "${var.install_dir}/${local.helm_charts_version}/configure.yaml"
}

# Download Helm charts tarball from the repository specified in the index file and save it to the installation directory.
resource "null_resource" "download_files" {
  count = fileexists(local.helm_charts_tarball) ? 0 : 1

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "python -m download_files -f ${var.index_file} -d ${var.install_dir}"
  }
}

# Extract the downloaded Helm charts tarball
resource "null_resource" "extract_files" {
  count = fileexists(local.helm_charts_tarball) ? 0 : 1

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "tar -xzf ${local.helm_charts_tarball}"
    working_dir = var.install_dir
  }

  depends_on = [
    null_resource.download_files
  ]
}

# Rename the extracted directory to the Helm charts version for easier reference in the Helm release resource.
resource "null_resource" "rename_files" {
  count = fileexists(local.helm_charts_tarball) ? 0 : 1

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "mv -T arcgis-enterprise ${local.helm_charts_version}"
    working_dir = var.install_dir
  }

  depends_on = [
    null_resource.extract_files
  ]
}
