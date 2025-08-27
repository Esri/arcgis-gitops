/**
 * # Application Terraform Module for ArcGIS Notebook Server on Linux
 *
 * The Terraform module configures or upgrades applications of highly available ArcGIS Notebook Server deployment on Linux platform.
 *
 * ![ArcGIS Notebook Server on Linux](arcgis-notebook-server-linux-application.png "ArcGIS Notebook Server on Linux")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment.
 *
 * If "is_upgrade" input variable is set to `true`, the module:
 *
 * * Copies the installation media for the ArcGIS Enterprise version specified by arcgis_version input variable to the private repository S3 bucket
 * * Downloads the installation media from the private repository S3 bucket to primary and node EC2 instances
 * * Installs/upgrades  ArcGIS Enterprise software on primary and node EC2 instances
 * * Installs the software patches on primary and node EC2 instances
 *
 * Then the module:
 *
 * * Copies the ArcGIS Notebook Server authorization file to the private repository S3 bucket
 * * If specified, copies keystore and root certificate files to the private repository S3 bucket
 * * Downloads the ArcGIS Notebook Server authorization file from the private repository S3 bucket to primary and node EC2 instances
 * * If specified, downloads the keystore and root certificate files from the private repository S3 bucket to primary and node EC2 instances
 * * Creates the required directories in the NFS mount
 * * Configures ArcGIS Notebook Server on primary EC2 instance
 * * Configures ArcGIS Notebook Server on node EC2 instance
 * * Deletes the downloaded setup archives, the extracted setups, and other temporary files from primary and node EC2 instances
 * * Subscribes the primary ArcGIS Notebook Server administrator e-mail address to the SNS topic of the monitoring subsystem
 *
 * ## Requirements
 *
 * The AWS resources for the deployment must be provisioned by Infrastructure terraform module for ArcGIS Notebook Server on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the arcgis-notebook-server-linux/application module path
 * * AWS credentials must be configured
 *
 * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
 *
 * ## SSM Parameters
 *
 * The module reads the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/backup/plan-id | Backup plan ID for the deployment |
 * | /arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket | S3 bucket for the portal content |
 * | /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the deployment |
 * | /arcgis/${var.site_id}/${var.deployment_id}/notebook-server-web-context | ArcGIS Notebook Server web context | 
 * | /arcgis/${var.site_id}/${var.deployment_id}/portal-url | Portal for ArcGIS URL (if portal_url is not specified) | 
 * | /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | SNS topic ARN of the monitoring subsystem |
 * | /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
 * | /arcgis/${var.site_id}/cookbooks-url | Chef cookbooks URL |
 * | /arcgis/${var.site_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |
 * | /arcgis/${var.site_id}/s3/backup | S3 bucket for the backup |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM command output |
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket for the private repository |
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

terraform {
  backend "s3" {
    key = "terraform/arcgis-enterprise/arcgis-notebook-server/application.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }

  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ArcGISAutomation   = "arcgis-gitops"
      ArcGISSiteId       = var.site_id
      ArcGISDeploymentId = var.deployment_id
    }
  }

  ignore_tags {
    keys = ["ArcGISVersion"]
  }
}

data "aws_ssm_parameter" "sns_topic" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn"
}

data "aws_ssm_parameter" "deployment_fqdn" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn"
}

data "aws_ssm_parameter" "notebook_server_web_context" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/notebook-server-web-context"
}

data "aws_ssm_parameter" "portal_url" {
  count = var.portal_url == null ? 1 : 0
  name  = "/arcgis/${var.site_id}/${var.deployment_id}/portal-url"
}

# Retrieve attributes of the primary EC2 instance
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

# Retrieve attributes of all the deployment's EC2 instances
data "aws_instances" "nodes" {
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
    values = ["node"]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running"]
  }
}

data "aws_region" "current" {}

locals {
  manifest_file_path = "../manifests/arcgis-notebook-server-s3files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  java_tarball       = local.manifest.arcgis.repository.metadata.java_tarball
  java_version       = local.manifest.arcgis.repository.metadata.java_version
  tomcat_tarball     = local.manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version     = local.manifest.arcgis.repository.metadata.tomcat_version

  authorization_files_s3_prefix = "software/authorization/${var.arcgis_version}"
  certificates_s3_prefix        = "software/certificates"

  mount_point             = "/mnt/efs"
  deployment_fqdn         = nonsensitive(data.aws_ssm_parameter.deployment_fqdn.value)
  notebook_server_web_context      = nonsensitive(data.aws_ssm_parameter.notebook_server_web_context.value)
  portal_url              = var.portal_url == null ? nonsensitive(data.aws_ssm_parameter.portal_url[0].value) : var.portal_url
  primary_hostname        = data.aws_instance.primary.private_ip
  software_dir            = "/opt/software/setups/*"
  authorization_files_dir = "/opt/software/authorization"
  certificates_dir        = "/opt/software/certificates"

  keystore_file = var.keystore_file_path != null ? "${local.certificates_dir}/${basename(var.keystore_file_path)}" : ""
  root_cert     = var.root_cert_file_path != null ? "${local.certificates_dir}/${basename(var.root_cert_file_path)}" : ""

  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

# Copy ArcGIS Notebook Server setup archives to the private repository S3 bucket
module "s3_copy_files" {
  count       = var.is_upgrade ? 1 : 0
  source      = "../../modules/s3_copy_files"
  bucket_name = module.site_core_info.s3_repository
  index_file  = local.manifest_file_path
}

# Install Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment
module "bootstrap_deployment" {
  source           = "../../modules/bootstrap"
  os               = var.os
  site_id          = var.site_id
  deployment_id    = var.deployment_id
  machine_roles    = ["primary", "node"]
  output_s3_bucket = module.site_core_info.s3_logs
}

# Download ArcGIS Notebook Server setup archives to primary and node EC2 instances
module "arcgis_notebook_server_files" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/files"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = templatefile(
    local.manifest_file_path,
    {
      s3bucket = module.site_core_info.s3_repository
      region   = module.site_core_info.s3_region
    }
  )
  execution_timeout = 1800
  depends_on = [
    module.bootstrap_deployment,
    module.s3_copy_files
  ]
}

# Upgrade ArcGIS Notebook Server software on primary and node EC2 instances
module "arcgis_notebook_server_upgrade" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/upgrade"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    java = {
      version      = local.java_version
      tarball_path = "${local.archives_dir}/${local.java_tarball}"
    }
    tomcat = {
      version      = local.tomcat_version
      tarball_path = "${local.archives_dir}/${local.tomcat_tarball}"
      install_path = "/opt/tomcat_arcgis_${local.tomcat_version}"
    }
    arcgis = {
      version          = var.arcgis_version
      run_as_user      = var.run_as_user
      configure_autofs = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis_${local.tomcat_version}/webapps"
      }
      notebook_server = {
        install_dir                 = "/opt"
        install_system_requirements = true
        license_level               = var.license_level
        configure_autostart         = true
        wa_name                     = local.notebook_server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat::openjdk]",
      "recipe[esri-tomcat::install]",
      "recipe[arcgis-notebooks::install_server]",
      "recipe[arcgis-notebooks::install_server_wa]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_notebook_server_files
  ]
}

# Patch ArcGIS Notebook Server software on primary and node EC2 instances
module "arcgis_notebook_server_patch" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/patch"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      repository = {
        patches = local.patches_dir
      }
      notebook_server = {
        install_dir = "/opt"
        patches     = var.arcgis_notebook_server_patches
      }
      web_adaptor = {
        install_dir = "/opt"
        patches     = var.arcgis_web_adaptor_patches
      }
    }
    run_list = [
      "recipe[arcgis-notebooks::install_patches]",
      "recipe[arcgis-enterprise::install_patches]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_notebook_server_upgrade
  ]
}

# Configure fileserver 
module "arcgis_notebook_server_fileserver" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/${var.arcgis_version}/fileserver"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      fileserver = {
        directories = [
          "${local.mount_point}/gisdata/notebookserver"
        ]
        shares = [
        ]
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::fileserver]"
    ]
  })
  depends_on = [
    module.bootstrap_deployment,
    module.arcgis_notebook_server_patch
  ]
}

# Upload ArcGIS Notebook Server authorization file to the private repository S3 bucket
resource "aws_s3_object" "notebook_server_authorization_file" {
  bucket = module.site_core_info.s3_repository
  key    = "${local.authorization_files_s3_prefix}/${basename(var.notebook_server_authorization_file_path)}"
  source = var.notebook_server_authorization_file_path
}

# If specified, upload keystore file to the private repository S3 bucket
resource "aws_s3_object" "keystore_file" {
  count  = var.keystore_file_path != null ? 1 : 0
  bucket = module.site_core_info.s3_repository
  key    = "${local.certificates_s3_prefix}/${basename(var.keystore_file_path)}"
  source = var.keystore_file_path
}

# If specified, upload root certificate file to the private repository S3 bucket
resource "aws_s3_object" "root_cert_file" {
  count  = var.root_cert_file_path != null ? 1 : 0
  bucket = module.site_core_info.s3_repository
  key    = "${local.certificates_s3_prefix}/${basename(var.root_cert_file_path)}"
  source = var.root_cert_file_path
}

# Download ArcGIS Notebook Server authorization file to primary and node EC2 instances
module "authorization_files" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/authorization-files"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.authorization_files_dir
        server = {
          s3bucket = module.site_core_info.s3_repository
          region   = module.site_core_info.s3_region
        }
        files = {
          "${basename(var.notebook_server_authorization_file_path)}" = {
            subfolder = local.authorization_files_s3_prefix
          }
        }
      }
    }
    run_list = [
      "recipe[arcgis-repository::s3files2]"
    ]
  })
  depends_on = [
    module.arcgis_notebook_server_fileserver,
    aws_s3_object.notebook_server_authorization_file
  ]
}

# Download keystore file to primary and node EC2 instances
module "keystore_file" {
  count          = var.keystore_file_path != null ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/keystore-file"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        server = {
          s3bucket = module.site_core_info.s3_repository
          region   = module.site_core_info.s3_region
        }
        files = {
          "${basename(var.keystore_file_path)}" = {
            subfolder = local.certificates_s3_prefix
          }
        }
      }
    }
    run_list = [
      "recipe[arcgis-repository::s3files2]"
    ]
  })
  depends_on = [
    module.authorization_files,
    aws_s3_object.keystore_file
  ]
}

# Download root certificate file to primary and node EC2 instances
module "root_cert" {
  count          = var.root_cert_file_path != null ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/root-cert"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        server = {
          s3bucket = module.site_core_info.s3_repository
          region   = module.site_core_info.s3_region
        }
        files = {
          "${basename(var.root_cert_file_path)}" = {
            subfolder = local.certificates_s3_prefix
          }
        }
      }
    }
    run_list = [
      "recipe[arcgis-repository::s3files2]"
    ]
  })
  depends_on = [
    module.authorization_files,
    module.keystore_file,
    aws_s3_object.root_cert_file
  ]
}

# Configure ArcGIS Notebook Server on primary EC2 instance
module "arcgis_notebook_server_primary" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/primary"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = local.deployment_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = var.keystore_file_password
    }
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis/webapps"
      }
      notebook_server = {
        url                   = "https://${local.primary_hostname}:11443/arcgis"
        wa_url                = "https://${local.primary_hostname}/${local.notebook_server_web_context}"
        install_dir           = "/opt"
        admin_username        = var.admin_username
        admin_password        = var.admin_password
        authorization_file    = "${local.authorization_files_dir}/${basename(var.notebook_server_authorization_file_path)}"
        authorization_options = var.notebook_server_authorization_options
        license_level         = var.license_level
        keystore_file         = local.keystore_file
        keystore_password     = var.keystore_file_password
        root_cert             = local.root_cert
        root_cert_alias       = "rootcert"
        directories_root      = "${local.mount_point}/gisdata/notebookserver"
        workspace             = "${local.mount_point}/gisdata/notebookserver/directories/arcgisworkspace"
        log_dir               = "${local.mount_point}/gisdata/notebookserver/logs"
        log_level             = var.log_level
        config_store_type     = var.config_store_type
        config_store_connection_string = (var.config_store_type == "AMAZON" ?
          "NAMESPACE=${var.site_id}-${var.deployment_id};REGION=${data.aws_region.current.region}" :
        "${local.mount_point}/gisdata/notebookserver/config-store")
        config_store_connection_secret = ""
        install_system_requirements    = true
        wa_name                        = local.notebook_server_web_context
        services_dir_enabled           = true
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[esri-tomcat]",
      "recipe[arcgis-notebooks::server]",
      "recipe[arcgis-notebooks::restart_docker]",
      "recipe[arcgis-notebooks::server_wa]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_notebook_server_fileserver,
    module.authorization_files,
    module.keystore_file,
    module.root_cert
  ]
}

# Configure ArcGIS Notebook Server on node EC2 instances if any
module "arcgis_notebook_server_node" {
  count = length(data.aws_instances.nodes.ids) > 0 ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/node"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["node"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = local.deployment_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = var.keystore_file_password
    }
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis/webapps"
      }
      notebook_server = {
        install_dir                 = "/opt"
        primary_server_url          = "https://${local.primary_hostname}:11443/arcgis"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        license_level               = var.license_level
        log_dir                     = "${local.mount_point}/gisdata/notebookserver/logs"
        authorization_file          = "${local.authorization_files_dir}/${basename(var.notebook_server_authorization_file_path)}"
        authorization_options       = var.notebook_server_authorization_options
        install_system_requirements = true
        wa_name                     = local.notebook_server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[esri-tomcat]",
      "recipe[arcgis-notebooks::server_node]",
      "recipe[arcgis-notebooks::restart_docker]",
      "recipe[arcgis-notebooks::server_wa]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_notebook_server_primary
  ]
}

# Federate ArcGIS Notebook Server with Portal for ArcGIS
module "arcgis_notebook_server_federation" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-notebook-server/federation"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      portal = {
        private_url     = local.portal_url
        admin_username  = var.portal_username
        admin_password  = var.portal_password
        root_cert       = ""
        root_cert_alias = "notebookserver"
      }
      notebook_server = {
        web_context_url = "https://${local.deployment_fqdn}/${local.notebook_server_web_context}"
        private_url     = "https://${local.deployment_fqdn}:11443/arcgis"
        admin_username  = var.admin_username
        admin_password  = var.admin_password
      }
    }
    run_list = [
      "recipe[arcgis-notebooks::federation]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_notebook_server_primary,
    module.arcgis_notebook_server_node
  ]
}

# System-level backups of the resources created by the application module
# using AWS Backup service.
module "backup" {
  count              = var.config_store_type == "AMAZON" ? 1 : 0
  source             = "../../modules/backup"
  arcgis_application = "server"
  arcgis_version     = var.arcgis_version
  deployment_id      = var.deployment_id
  site_id            = var.site_id

  depends_on = [
    module.arcgis_notebook_server_primary
  ]
}

# Delete the downloaded setup archives, the extracted setups, and other 
# temporary files from primary and node EC2 instances.
module "clean_up" {
  source                = "../../modules/clean_up"
  site_id               = var.site_id
  deployment_id         = var.deployment_id
  machine_roles         = ["primary", "node"]
  directories           = [local.software_dir]
  uninstall_chef_client = false
  depends_on = [
    module.arcgis_notebook_server_federation
  ]
}

resource "aws_sns_topic_subscription" "infrastructure_alarms" {
  topic_arn = data.aws_ssm_parameter.sns_topic.value
  protocol  = "email"
  endpoint  = var.admin_email
  depends_on = [
    module.arcgis_notebook_server_primary,
    module.arcgis_notebook_server_node
  ]
}

