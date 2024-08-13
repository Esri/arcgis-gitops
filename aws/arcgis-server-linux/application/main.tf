/**
 * # Application Terraform Module for ArcGIS Server on Linux
 *
 * The Terraform module configures or upgrades applications of highly available ArcGIS Server deployment on Linux platform.
 *
 * ![ArcGIS Server on Linux](arcgis-server-linux-application.png "ArcGIS Server on Linux")
 *
 * If is_upgrade input variable is set to true, the module:
 *
 * * Copies the installation media for the ArcGIS Server version specified by arcgis_version input variable to the private repository S3 bucket
 * * Downloads the installation media from the private repository S3 bucket to primary and node EC2 instances
 * * Upgrades ArcGIS Server on primary and node EC2 instances
 * * Installs ArcGIS Server patches on primary and node EC2 instances
 * * If configure_webadaptor input variable is set to true, upgrades OpenJDK, Apache Tomcat, and ArcGIS Web Adaptor on primary and node EC2 instances
 *
 * Then the module:
 *
 * * Creates the required directories in the NFS mount
 * * Copies the ArcGIS Server authorization file to the EC2 instances
 * * Configures ArcGIS Server on primary EC2 instance
 * * Configures ArcGIS Server on node EC2 instances
 * * If configure_webadaptor input variable is set to true:
 * * * Configures HTTPS listener in Apache Tomcat on primary and node EC2 instances to use either the SSL certificate specified by keystore_file_path input variable or a self signed certificate if keystore_file_path is not specified
 * * * Registers ArcGIS Web Adaptor with ArcGIS Server on primary and node EC2 instances
 * * If server_role is specified, federates ArcGIS Server with Portal for ArcGIS
 *
 * ## Requirements
 *
 * The AWS resources for the deployment must be provisioned by Infrastructure terraform module for ArcGIS Server on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * Ansible 2.16 or later must be installed
 * * arcgis.common, arcgis.server, and arcgis.portal Ansible collections must be installed
 * * The working directury must be set to the arcgis-server-linux/application module path
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 *
 * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
 *
 * ## SSM Parameters
 *
 * The module uses the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | SNS topic ARN of the monitoring subsystem |
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket for the private repository |
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

terraform {
  backend "s3" {
    key = "terraform/arcgis-enterprise/arcgis-server/application.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }

  required_version = ">= 1.1.9"
}

provider "aws" {
  default_tags {
    tags = {
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }

  ignore_tags {
    keys = ["ArcGISVersion"]
  }
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.site_id}/s3/repository"
}

data "aws_ssm_parameter" "sns_topic" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn"
}

# Retrieve attributes of primary EC2 instance
data "aws_instance" "primary" {
  filter {
    name   = "tag:ArcGISSiteId"
    values = [var.site_id]
  }

  filter {
    name   = "tag:ArcGISDeploymentId"
    values = [var.deployment_id]
  }

  filter {
    name   = "tag:ArcGISMachineRole"
    values = ["primary"]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running"]
  }
}

data "aws_region" "current" {}

locals {
  server_manifest_path    = "${abspath(path.root)}/../manifests/arcgis-server-s3files-${var.arcgis_version}.json"
  mount_point             = "/mnt/efs"
  primary_hostname        = data.aws_instance.primary.private_ip
  software_dir            = "/opt/software/*"
  authorization_files_dir = "/opt/software/authorization"
  keystore_file           = "/opt/software/certificate.pfx"
  timestamp               = formatdate("YYYYMMDDhhmm", timestamp())
}

# Copy ArcGIS Server setup archives to the private repository S3 bucket
module "copy_server_files" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/s3_copy_files"
  bucket_name            = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  index_file             = local.server_manifest_path
  arcgis_online_username = var.arcgis_online_username
  arcgis_online_password = var.arcgis_online_password
}

# Download ArcGIS Server setup archives from the private repository S3 bucket
# to /opt/software/archives directory on primary and node EC2 instances.
module "arcgis_server_files" {
  count         = var.is_upgrade ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.s3_files"
  external_vars = {
    local_repository = "/opt/software/archives"
    manifest         = local.server_manifest_path
    bucket_name      = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
    region           = data.aws_region.current.name
  }
  depends_on = [
    module.copy_server_files
  ]
}

# Unregister ArcGIS Web Adaptor from the node EC2 instance before upgrading.
module "unregister_web_adaptors" {
  count         = var.is_upgrade && var.configure_webadaptor ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["node"]
  playbook      = "arcgis.server.unregister_wa"
  external_vars = {
    admin_username = var.admin_username
    admin_password = var.admin_password
  }
}

# Upgrade ArcGIS Server on primary and node EC2 instances
module "arcgis_server_upgrade" {
  count         = var.is_upgrade ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.server.install"
  external_vars = {
    arcgis_version   = var.arcgis_version
    install_dir      = "/opt"
    local_repository = "/opt/software/archives"
    run_as_user      = var.run_as_user
  }
  depends_on = [
    module.arcgis_server_files,
    module.unregister_web_adaptors
  ]
}

# Install ArcGIS Server patches on primary and node EC2 instances
module "arcgis_server_patch" {
  count         = var.is_upgrade ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.server.patch"
  external_vars = {
    arcgis_version        = var.arcgis_version
    arcgis_server_patches = var.arcgis_server_patches
    install_dir           = "/opt"
    patches_directory     = "/opt/software/archives/patches"
    run_as_user           = var.run_as_user
  }
  depends_on = [
    module.arcgis_server_upgrade
  ]
}

# Configure EFS fileserver
module "arcgis_server_fileserver" {
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary"]
  playbook      = "arcgis.server.fileserver"
  external_vars = {
    run_as_user = var.run_as_user
    fileserver_directories = [
      "${local.mount_point}/gisdata/arcgisserver",
      "${local.mount_point}/gisdata/arcgisserver/backups",
    ]
  }
  depends_on = [
    module.arcgis_server_patch
  ]
}

# Copy ArcGIS Server authorization file to primary and node EC2 instances
module "authorization_file" {
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.file"
  external_vars = {
    src_file  = var.server_authorization_file_path
    dest_file = "${local.authorization_files_dir}/"
  }
}

# Copy keystore file to primary and node EC2 instances
module "keystore_file" {
  count         = var.keystore_file_path != null ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.file"
  external_vars = {
    src_file  = var.keystore_file_path
    dest_file = local.keystore_file
  }
}

# Authorize ArcGIS Server on primary machine, create an ArcGIS Server site,
# set the site's system properties, and configure SSL certificates of the machine.
module "arcgis_server_primary" {
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary"]
  playbook      = "arcgis.server.primary"
  external_vars = {
    install_dir        = "/opt"
    authorization_file = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
    authorization_options = var.server_authorization_options
    admin_username     = var.admin_username
    admin_password     = var.admin_password
    directories_root   = "${local.mount_point}/gisdata/arcgisserver"
    config_store_type  = var.config_store_type
    config_store_connection_string = (var.config_store_type == "AMAZON" ?
      "NAMESPACE=${var.deployment_id}-${local.timestamp};REGION=${data.aws_region.current.name}" :
    "${local.mount_point}/gisdata/arcgisserver/config-store")
    config_store_connection_secret = ""
    log_level                      = var.log_level
    log_dir                        = "/opt/arcgis/server/usr/logs"
    max_log_file_age               = 90
    run_as_user                    = var.run_as_user
    system_properties              = var.system_properties
    services_dir_enabled           = var.services_dir_enabled
    keystore_file                  = local.keystore_file
    keystore_password              = var.keystore_file_password
    cert_alias                     = var.deployment_fqdn
  }
  depends_on = [
    module.authorization_file,
    module.arcgis_server_fileserver
  ]
}

# Authorize ArcGIS Server on the node machines, join the machines to
# an existing ArcGIS Server site, and configure SSL certificates of the machines.
module "arcgis_server_node" {
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["node"]
  playbook      = "arcgis.server.node"
  external_vars = {
    install_dir        = "/opt"
    authorization_file = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
    authorization_options = var.server_authorization_options
    admin_username     = var.admin_username
    admin_password     = var.admin_password
    primary_server_url = "https://${local.primary_hostname}:6443/arcgis"
    run_as_user        = var.run_as_user
    keystore_file      = local.keystore_file
    keystore_password  = var.keystore_file_password
    cert_alias         = var.deployment_fqdn
  }
  depends_on = [
    module.authorization_file,
    module.arcgis_server_primary
  ]
}

# Delete temporary files
module "clean" {
  count         = var.is_upgrade ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
  playbook      = "arcgis.common.clean"
  external_vars = {}
  depends_on = [
    module.arcgis_server_node,
    module.arcgis_webadaptor
  ]
}

# Federate ArcGIS Server with Portal for ArcGIS if server_role is specified.
module "arcgis_server_federation" {
  count         = var.server_role != "" ? 1 : 0
  source        = "../../modules/ansible_playbook"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary"]
  playbook      = "arcgis.portal.federate_server"
  external_vars = {
    portal_org_id    = var.portal_org_id
    portal_url       = var.portal_url
    username         = var.portal_username
    password         = var.portal_password
    server_url       = "https://${var.deployment_fqdn}/${var.web_context}"
    server_admin_url = "https://${var.deployment_fqdn}:6443/arcgis"
    server_username  = var.admin_username
    server_password  = var.admin_password
    server_role      = var.server_role
    server_function  = join(",", var.server_functions)
  }
  depends_on = [
    module.arcgis_server_node,
    module.arcgis_webadaptor
  ]
}

# Create SNS topic subscription for infrastructure alarms
resource "aws_sns_topic_subscription" "infrastructure_alarms" {
  topic_arn = data.aws_ssm_parameter.sns_topic.value
  protocol  = "email"
  endpoint  = var.admin_email
  depends_on = [
    module.arcgis_server_node,
    module.arcgis_server_federation
  ]
}
