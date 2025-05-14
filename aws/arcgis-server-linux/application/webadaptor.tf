# Copyright 2024-2025 Esri
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

# Upgrade and configure ArcGIS Web Adaptor 

locals {
  webadaptor_manifest_path = "${abspath(path.root)}/../manifests/arcgis-webadaptor-s3files-${var.arcgis_version}.json"
  webadaptor_manifest      = jsondecode(file(local.webadaptor_manifest_path))
  java_tarball             = local.webadaptor_manifest.arcgis.repository.metadata.java_tarball
  java_version             = local.webadaptor_manifest.arcgis.repository.metadata.java_version
  tomcat_tarball           = local.webadaptor_manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version           = local.webadaptor_manifest.arcgis.repository.metadata.tomcat_version
  tomcat_keystore_file     = "/opt/tomcat_arcgis/conf/certificate.pfx"
}

# Copy ArcGIS Web Adaptor, OpenJDK, and Apache Tomcat setup archives to the private repository S3 bucket.
module "copy_webadaptor_files" {
  count       = var.is_upgrade && var.use_webadaptor ? 1 : 0
  source      = "../../modules/s3_copy_files"
  bucket_name = module.site_core_info.s3_repository
  index_file  = local.webadaptor_manifest_path
  depends_on = [
    module.arcgis_server_node
  ]
}

# Download ArcGIS Web Adaptor, OpenJDK, and Apache Tomcat setup archives from the private repository S3 bucket.
module "download_webadaptor_files" {
  count         = var.is_upgrade && var.use_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.s3_files"
  external_vars = {
    local_repository = local.archives_dir
    manifest         = local.webadaptor_manifest_path
    bucket_name      = module.site_core_info.s3_repository
    region           = module.site_core_info.s3_region
  }
  depends_on = [
    module.copy_webadaptor_files
  ]
}

# Copy keystore file to primary and node EC2 instances
module "tomcat_keystore_file" {
  count         = var.keystore_file_path != null ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.file"
  external_vars = {
    src_file  = var.keystore_file_path
    dest_file = local.tomcat_keystore_file
  }
}

# Upgrade OpenJDK on primary and node EC2 instances
module "openjdk_upgrade" {
  count         = var.is_upgrade && var.use_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.openjdk"
  external_vars = {
    jdk_version       = local.java_version
    jdk_setup_archive = local.java_tarball
    install_dir       = "/opt"
    local_repository  = local.archives_dir
  }
  depends_on = [
    module.download_webadaptor_files
  ]
}

# Upgrade Tomcat on primary and node EC2 instances
module "tomcat_upgrade" {
  count         = var.is_upgrade && var.use_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.tomcat"
  external_vars = {
    tomcat_version       = local.tomcat_version
    tomcat_setup_archive = local.tomcat_tarball
    install_dir          = "/opt"
    local_repository     = local.archives_dir
  }
  depends_on = [
    module.openjdk_upgrade
  ]
}

# Upgrade ArcGIS Web Adaptor on primary and node EC2 instances
module "arcgis_webadaptor_upgrade" {
  count         = var.is_upgrade && var.use_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.install"
  external_vars = {
    arcgis_version   = var.arcgis_version
    install_dir      = "/opt"
    local_repository = local.archives_dir
    run_as_user      = var.run_as_user
  }
  depends_on = [
    module.arcgis_server_upgrade,
    module.tomcat_upgrade
  ]
}

# Configure SSL in Tomcat on primary and node EC2 instances
module "tomcat_ssl_config" {
  count         = var.use_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.tomcat_ssl_config"
  external_vars = {
    keystore_file     = local.keystore_file
    keystore_password = var.keystore_file_password != "" ? var.keystore_file_password : "changeit"
  }
  depends_on = [
    module.arcgis_server_primary,
    module.arcgis_server_node,
    module.arcgis_webadaptor_upgrade,
    module.tomcat_keystore_file
  ]
}

# Configure ArcGIS Web Adaptor on primary and node EC2 instances
module "arcgis_webadaptor" {
  count         = var.use_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.configure"
  external_vars = {
    arcgis_version = var.arcgis_version
    install_dir    = "/opt"
    run_as_user    = var.run_as_user
    wa_name        = local.server_web_context
    admin_username = var.admin_username
    admin_password = var.admin_password
    admin_access   = true
  }
  depends_on = [
    module.tomcat_ssl_config
  ]
}
