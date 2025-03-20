/**
 * # Application Terraform Module for Base ArcGIS Enterprise on Linux
 *
 * The Terraform module configures or upgrades applications of highly available base ArcGIS Enterprise deployment on Linux platform.
 *
 * ![Base ArcGIS Enterprise on Linux](arcgis-enterprise-base-linux-application.png "Base ArcGIS Enterprise on Linux")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment.
 *
 * If "is_upgrade" input variable is set to `true`, the module:
 *
 * * Unregisters ArcGIS Server's Web Adaptor on standby EC2 instance
 * * Copies the installation media for the ArcGIS Enterprise version specified by arcgis_version input variable to the private repository S3 bucket
 * * Downloads the installation media from the private repository S3 bucket to primary and standby EC2 instances
 * * Installs/upgrades  ArcGIS Enterprise software on primary and standby EC2 instances
 * * Installs the software patches on primary and standby EC2 instances
 *
 * Then the module:
 *
 * * Copies the ArcGIS Server and Portal for ArcGIS authorization files to the private repository S3 bucket
 * * If specified, copies keystore and root certificate files to the private repository S3 bucket
 * * Downloads the ArcGIS Server and Portal for ArcGIS authorization files from the private repository S3 bucket to primary and standby EC2 instances
 * * If specified, downloads the keystore and root certificate files from the private repository S3 bucket to primary and standby EC2 instances
 * * Creates the required directories in the NFS mount
 * * Configures base ArcGIS Enterprise on primary EC2 instance
 * * Configures base ArcGIS Enterprise on standby EC2 instance
 * * Deletes the downloaded setup archives, the extracted setups, and other temporary files from primary and standby EC2 instances
 * * Subscribes the primary ArcGIS Enterprise administrator e-mail address to the SNS topic of the monitoring subsystem
 *
 * ## Requirements
 *
 * The AWS resources for the deployment must be provisioned by Infrastructure terraform module for base ArcGIS Enterprise on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the arcgis-enterprise-base-linux/application module path
 * * AWS credentials must be configured
 *
 * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
 *
 * ## SSM Parameters
 *
 * The module uses the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket | S3 bucket for the portal content |
 * | /arcgis/${var.site_id}/${var.deployment_id}/object-store-s3-bucket | S3 bucket for the object store |
 * | /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | SNS topic ARN of the monitoring subsystem |
 * | /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
 * | /arcgis/${var.site_id}/cookbooks-url | Chef cookbooks URL |
 * | /arcgis/${var.site_id}/s3/backup | S3 bucket for the backup |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM command output |
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket for the private repository |
 */

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

terraform {
  backend "s3" {
    key = "terraform/arcgis-enterprise/arcgis-enterprise-base/application.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
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

data "aws_ssm_parameter" "s3_content" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket"
}

data "aws_ssm_parameter" "object_store" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/object-store-s3-bucket"
}

data "aws_ssm_parameter" "sns_topic" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn"
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

# Retrieve attributes of the standby EC2 instance
data "aws_instance" "standby" {
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
    values = ["standby"]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running"]
  }
}

# Retrieve attributes of all the deployment's EC2 instances
data "aws_instances" "deployment" {
  filter {
    name   = "tag:ArcGISSiteId"
    values = [var.site_id]
  }

  filter {
    name   = "tag:ArcGISDeploymentId"
    values = [var.deployment_id]
  }

  filter {
    name   = "instance-state-name"
    values = ["pending", "running"]
  }
}

data "aws_region" "current" {}

locals {
  manifest_file_path = "../manifests/arcgis-enterprise-s3files-${var.arcgis_version}.json"
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
  primary_hostname        = "primary.${var.deployment_id}.${var.site_id}.internal"
  standby_hostname        = "standby.${var.deployment_id}.${var.site_id}.internal"
  software_dir            = "/opt/software/*"
  authorization_files_dir = "/opt/software/authorization"
  certificates_dir        = "/opt/software/certificates"

  keystore_file = var.keystore_file_path != null ? "${local.certificates_dir}/${basename(var.keystore_file_path)}" : ""
  root_cert     = var.root_cert_file_path != null ? "${local.certificates_dir}/${basename(var.root_cert_file_path)}" : ""

  timestamp     = formatdate("YYYYMMDDhhmm", timestamp())
}

module "site_core_info" {
  source         = "../../modules/site_core_info"
  site_id        = var.site_id
}

# Copy ArcGIS Enterprise setup archives of the ArcGIS Enterprise version to the private repository S3 bucket
module "s3_copy_files" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/s3_copy_files"
  bucket_name            = module.site_core_info.s3_repository
  index_file             = local.manifest_file_path
}

# Install Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment
module "bootstrap_deployment" {
  source        = "../../modules/bootstrap"
  os            = var.os
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "standby"]
  output_s3_bucket = module.site_core_info.s3_logs
}

# Download base ArcGIS Enterprise setup archives to primary and standby EC2 instances
module "arcgis_enterprise_files" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/files"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "standby"]
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

# If it's an upgrade, unregister ArcGIS Server's Web Adaptor on standby EC2 instance
module "begin_upgrade_standby" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/begin-upgrade-standby"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["standby"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      configure_cloud_settings   = false
      server = {
        admin_username = var.admin_username
        admin_password = var.admin_password
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::unregister_server_wa]"
    ]
  })
  execution_timeout = 600
  depends_on = [
    module.arcgis_enterprise_files
  ]
}

# Upgrade base ArcGIS Enterprise software on primary and standby EC2 instances
module "arcgis_enterprise_upgrade" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/upgrade"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "standby"]
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
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis_${local.tomcat_version}/webapps"
      }
      server = {
        install_dir                 = "/opt"
        configure_autostart         = true
        install_system_requirements = true
        wa_name                     = var.server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
      data_store = {
        install_dir                 = "/opt"
        setup_options               = "-f Relational"
        data_dir                    = "/gisdata/arcgisdatastore"
        configure_autostart         = true
        preferredidentifier         = "hostname"
        install_system_requirements = true
      }
      portal = {
        install_dir                 = "/opt"
        configure_autostart         = true
        install_system_requirements = true
        wa_name                     = var.portal_web_context
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat::openjdk]",
      "recipe[esri-tomcat]",
      "recipe[arcgis-enterprise::stop_portal]",      
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::start_portal]",
      "recipe[arcgis-enterprise::install_portal_wa]",
      "recipe[arcgis-enterprise::stop_server]",
      "recipe[arcgis-enterprise::install_server]",
      "recipe[arcgis-enterprise::start_server]",
      "recipe[arcgis-enterprise::install_server_wa]",
      "recipe[arcgis-enterprise::stop_datastore]",
      "recipe[arcgis-enterprise::install_datastore]",
      "recipe[arcgis-enterprise::start_datastore]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.begin_upgrade_standby
  ]
}

# Patch base ArcGIS Enterprise software on primary and standby EC2 instances
module "arcgis_enterprise_patch" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/patch"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        patches = local.patches_dir
      }
      portal = {
        install_dir = "/opt"
        patches     = var.arcgis_portal_patches
      }
      server = {
        install_dir = "/opt"
        patches     = var.arcgis_server_patches
      }
      data_store = {
        install_dir = "/opt"
        patches     = var.arcgis_data_store_patches
      }
      web_adaptor = {
        install_dir = "/opt"
        patches     = var.arcgis_web_adaptor_patches
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::install_patches]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_enterprise_upgrade
  ]
}

# Update ArcGISVersion tag on the EC2 instances after upgrade is complete.
resource "aws_ec2_tag" "arcgis_version" {
  count       = length(data.aws_instances.deployment.ids)
  resource_id = data.aws_instances.deployment.ids[count.index]
  key         = "ArcGISVersion"
  value       = var.arcgis_version
  depends_on = [
    module.arcgis_enterprise_upgrade
  ]
}

# Configure fileserver 
module "arcgis_enterprise_fileserver" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/${var.arcgis_version}/fileserver"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      fileserver = {
        directories = [
          "${local.mount_point}/gisdata/arcgisserver",
          "${local.mount_point}/gisdata/arcgisbackup/webgisdr"
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
    module.arcgis_enterprise_patch
  ]
}

# Upload ArcGIS Server authorization file to the private repository S3 bucket
resource "aws_s3_object" "server_authorization_file" {
  bucket = module.site_core_info.s3_repository
  key    = "${local.authorization_files_s3_prefix}/${basename(var.server_authorization_file_path)}"
  source = var.server_authorization_file_path
}

# Upload Portal for ArcGIS authorization file to the private repository S3 bucket
resource "aws_s3_object" "portal_authorization_file" {
  bucket = module.site_core_info.s3_repository
  key    = "${local.authorization_files_s3_prefix}/${basename(var.portal_authorization_file_path)}"
  source = var.portal_authorization_file_path
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

# Download ArcGIS Server authorization file to primary and standby EC2 instances
module "authorization_files" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/authorization-files"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.authorization_files_dir
        server = {
          s3bucket = module.site_core_info.s3_repository
          region   = module.site_core_info.s3_region
        }
        files = {
          "${basename(var.server_authorization_file_path)}" = {
            subfolder = local.authorization_files_s3_prefix
          }
          "${basename(var.portal_authorization_file_path)}" = {
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
    module.arcgis_enterprise_fileserver,
    aws_s3_object.server_authorization_file,
    aws_s3_object.portal_authorization_file
  ]
}

# Download keystore file to primary and standby EC2 instances
module "keystore_file" {
  count          = var.keystore_file_path != null ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/keystore-file"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
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

# Download root certificate file to primary and standby EC2 instances
module "root_cert" {
  count          = var.root_cert_file_path != null ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/root-cert"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
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

# Configure base ArcGIS Enterprise on primary EC2 instance
module "arcgis_enterprise_primary" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/primary"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = var.deployment_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = var.keystore_file_password
    }
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis/webapps"
      }
      server = {
        url                            = "https://${local.primary_hostname}:6443/arcgis"
        wa_url                         = "https://${local.primary_hostname}/${var.server_web_context}"
        install_dir                    = "/opt"
        private_url                    = "https://${var.deployment_fqdn}/${var.server_web_context}"
        web_context_url                = "https://${var.deployment_fqdn}/${var.server_web_context}"
        hostname                       = local.primary_hostname
        admin_username                 = var.admin_username
        admin_password                 = var.admin_password
        authorization_file             = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
        authorization_options          = var.server_authorization_options
        keystore_file                  = local.keystore_file
        keystore_password              = var.keystore_file_password
        root_cert                      = local.root_cert
        root_cert_alias                = "rootcert"
        directories_root               = "${local.mount_point}/gisdata/arcgisserver"
        log_dir                        = "/opt/arcgis/server/usr/logs"
        log_level                      = var.log_level
        config_store_type              = var.config_store_type
        config_store_connection_string = (var.config_store_type == "AMAZON" ?
          "NAMESPACE=${var.deployment_id}-${local.timestamp};REGION=${data.aws_region.current.name}" :
          "${local.mount_point}/gisdata/arcgisserver/config-store")
        config_store_connection_secret = ""
        install_system_requirements    = true
        wa_name                        = var.server_web_context
        services_dir_enabled           = true
        system_properties = {
          WebContextURL = "https://${var.deployment_fqdn}/${var.server_web_context}"
        }
        # Configure the object store in S3 bucket
        data_items = [{
          path = "/cloudStores/cloudObjectStore"
          type = "objectStore"
          provider = "amazon"
          info = {
            isManaged = true
            systemManaged = false
            isManagedData = true
            purposes = [ "feature-tile", "scene" ]
            connectionString = jsonencode({
              regionEndpointUrl = "https://s3.${data.aws_region.current.name}.amazonaws.com"
              defaultEndpointsProtocol = "https"
              credentialType = "IAMRole"
              region = data.aws_region.current.name
            })
            objectStore = "${nonsensitive(data.aws_ssm_parameter.object_store.value)}/store"
            encryptAttributes = [ "info.connectionString" ]
          }
        }]
      }
      data_store = {
        install_dir                 = "/opt"
        setup_options               = "-f Relational"
        data_dir                    = "/gisdata/arcgisdatastore"
        preferredidentifier         = "hostname"
        hostidentifier              = local.primary_hostname
        install_system_requirements = true
        types                       = "relational"
        relational = {
          backup_type     = "s3"
          backup_location = "type=s3;location=${nonsensitive(module.site_core_info.s3_backup)}/relational-${local.timestamp};name=re_default;region=${module.site_core_info.s3_region}"
        }
      }
      portal = {
        url                      = "https://${local.primary_hostname}:7443/arcgis"
        wa_url                   = "https://${local.primary_hostname}/${var.portal_web_context}"
        private_url              = "https://${var.deployment_fqdn}/${var.portal_web_context}"
        hostname                 = local.primary_hostname
        hostidentifier           = local.primary_hostname
        preferredidentifier      = "hostname"
        install_dir              = "/opt"
        admin_username           = var.admin_username
        admin_password           = var.admin_password
        admin_email              = var.admin_email
        admin_full_name          = var.admin_full_name
        admin_description        = var.admin_description
        security_question        = var.security_question
        security_question_answer = var.security_question_answer
        log_dir                  = "/opt/arcgis/portal/usr/arcgisportal/logs"
        log_level                = var.log_level
        enable_debug             = false
        content_store_type       = "CloudStore"
        content_store_provider   = "Amazon"
        content_store_connection_string = {
          region         = data.aws_region.current.name
          credentialType = "IAMRole"
        }
        object_store                = nonsensitive(data.aws_ssm_parameter.s3_content.value)
        authorization_file          = "${local.authorization_files_dir}/${basename(var.portal_authorization_file_path)}"
        user_license_type_id        = var.portal_user_license_type_id
        keystore_file               = local.keystore_file
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        install_system_requirements = true
        wa_name                     = var.portal_web_context
        system_properties = {
          privatePortalURL = "https://${var.deployment_fqdn}/${var.portal_web_context}"
          WebContextURL    = "https://${var.deployment_fqdn}/${var.portal_web_context}"
        }
      }
      web_adaptor = {
        install_dir            = "/opt"
        admin_access           = true
        reindex_portal_content = false
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal]",
      "recipe[arcgis-enterprise::portal_wa]",
      "recipe[arcgis-enterprise::server]",
      "recipe[arcgis-enterprise::server_wa]",
      "recipe[arcgis-enterprise::datastore]",
      "recipe[arcgis-enterprise::server_data_items]",
      "recipe[arcgis-enterprise::federation]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.arcgis_enterprise_fileserver,
    module.authorization_files,
    module.keystore_file,
    module.root_cert
  ]
}

# Configure base ArcGIS Enterprise on standby EC2 instance
module "arcgis_enterprise_standby" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/standby"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["standby"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = var.deployment_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = var.keystore_file_password
    }
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis/webapps"
      }
      server = {
        url                         = "https://${local.standby_hostname}:6443/arcgis"
        wa_url                      = "https://${local.standby_hostname}/${var.server_web_context}"
        hostname                    = local.standby_hostname   
        install_dir                 = "/opt"
        primary_server_url          = "https://${local.primary_hostname}/${var.server_web_context}"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        log_dir                     = "/opt/arcgis/server/usr/logs"
        authorization_file          = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
        authorization_options       = var.server_authorization_options
        keystore_file               = local.keystore_file
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        install_system_requirements = true
        wa_name                     = var.server_web_context
      }
      data_store = {
        install_dir                 = "/opt"
        setup_options               = "-f Relational"
        data_dir                    = "/gisdata/arcgisdatastore"
        preferredidentifier         = "hostname"
        hostidentifier              = local.standby_hostname
        install_system_requirements = true
        types                       = "relational"
      }
      portal = {
        url                         = "https://${local.standby_hostname}:7443/arcgis"
        wa_url                      = "https://${local.standby_hostname}/${var.portal_web_context}"
        hostname                    = local.standby_hostname   
        hostidentifier              = local.standby_hostname
        install_dir                 = "/opt"
        primary_machine_url         = "https://${local.primary_hostname}:7443"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        log_dir                     = "/opt/arcgis/portal/usr/arcgisportal/logs"
        keystore_file               = local.keystore_file
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        install_system_requirements = true
        wa_name                     = var.portal_web_context
      }
      web_adaptor = {
        install_dir            = "/opt"
        admin_access           = true
        reindex_portal_content = false
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal_standby]",
      "recipe[arcgis-enterprise::portal_wa]",
      "recipe[arcgis-enterprise::server_node]",
      "recipe[arcgis-enterprise::server_wa]",
      "recipe[arcgis-enterprise::datastore_standby]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.arcgis_enterprise_primary
  ]
}

# Delete the downloaded setup archives, the extracted setups, and other 
# temporary files from primary and standby EC2 instances.
module "clean_up" {
  source        = "../../modules/clean_up"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "standby"]
  directories   = [local.software_dir]
  uninstall_chef_client = false
  depends_on = [
    module.arcgis_enterprise_standby
  ]
}

resource "aws_sns_topic_subscription" "infrastructure_alarms" {
  topic_arn = data.aws_ssm_parameter.sns_topic.value
  protocol  = "email"
  endpoint  = var.admin_email
  depends_on = [ 
    module.arcgis_enterprise_standby
  ]
}

