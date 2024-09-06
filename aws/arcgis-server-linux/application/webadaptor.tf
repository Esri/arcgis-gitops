# Upgrade and configure ArcGIS Web Adaptor 

locals {
  webadaptor_manifest_path = "${abspath(path.root)}/../manifests/arcgis-webadaptor-s3files-${var.arcgis_version}.json"
  webadaptor_manifest      = jsondecode(file(local.webadaptor_manifest_path))
  tomcat_keystore_file     = "/opt/tomcat_arcgis/conf/certificate.pfx"
}

# Copy ArcGIS Web Adaptor, OpenJDK, and Apache Tomcat setup archives to the private repository S3 bucket.
module "copy_webadaptor_files" {
  count                  = var.is_upgrade && var.configure_webadaptor ? 1 : 0
  source                 = "../../modules/s3_copy_files"
  bucket_name            = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  index_file             = local.webadaptor_manifest_path
  depends_on = [
    module.arcgis_server_node
  ]
}

# Download ArcGIS Web Adaptor, OpenJDK, and Apache Tomcat setup archives from the private repository S3 bucket.
module "download_webadaptor_files" {
  count         = var.is_upgrade && var.configure_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.s3_files"
  external_vars = {
    local_repository = "/opt/software/archives"
    manifest         = local.webadaptor_manifest_path
    bucket_name      = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
    region           = data.aws_region.current.name
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
  count         = var.is_upgrade && var.configure_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.openjdk"
  external_vars = {
    jdk_version      = local.webadaptor_manifest.arcgis.repository.files["jdk_x64_linux.tar.gz"].version
    install_dir      = "/opt"
    local_repository = "/opt/software/archives"
  }
  depends_on = [
    module.download_webadaptor_files
  ]
}

# Upgrade Tomcat on primary and node EC2 instances
module "tomcat_upgrade" {
  count         = var.is_upgrade && var.configure_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.tomcat"
  external_vars = {
    tomcat_version   = local.webadaptor_manifest.arcgis.repository.files["tomcat.tar.gz"].version
    install_dir      = "/opt"
    local_repository = "/opt/software/archives"
  }
  depends_on = [
    module.openjdk_upgrade
  ]
}

# Upgrade ArcGIS Web Adaptor on primary and node EC2 instances
module "arcgis_webadaptor_upgrade" {
  count         = var.is_upgrade && var.configure_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.install"
  external_vars = {
    arcgis_version   = var.arcgis_version
    install_dir      = "/opt"
    local_repository = "/opt/software/archives"
    run_as_user      = var.run_as_user
  }
  depends_on = [
    module.arcgis_server_upgrade,
    module.tomcat_upgrade
  ]
}

# Configure SSL in Tomcat on primary and node EC2 instances
module "tomcat_ssl_config" {
  count         = var.configure_webadaptor ? 1 : 0
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
  count         = var.configure_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.webadaptor.configure"
  external_vars = {
    arcgis_version = var.arcgis_version
    install_dir    = "/opt"
    run_as_user    = var.run_as_user
    wa_name        = var.web_context
    admin_username = var.admin_username
    admin_password = var.admin_password
    admin_access   = true
  }
  depends_on = [
    module.tomcat_ssl_config
  ]
}
