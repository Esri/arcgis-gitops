/**
 * # Application Terraform Module for Base ArcGIS Enterprise on Windows
 *
 * The Terraform module configures or upgrades applications of highly available base ArcGIS Enterprise deployment on Windows platform.
 *
 * ![Base ArcGIS Enterprise on Windows](arcgis-enterprise-base-windows-application.png "Base ArcGIS Enterprise on Windows")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment.
 *
 * If is_upgrade input variable is set to true, the module:
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
 * * Creates the required network shares and directories in the fileserver EC2 instance
 * * Configures base ArcGIS Enterprise on primary EC2 instance
 * * Configures base ArcGIS Enterprise on standby EC2 instance
 * * Deletes the downloaded setup archives, the extracted setups, and other temporary files from primary and standby EC2 instances
 * * Subscribes the primary ArcGIS Enterprise administrator e-mail address to the SNS topic of the monitoring subsystem
 *
 * ## Requirements
 *
 * The AWS resources for the deployment must be provisioned by Infrastructure terraform module for base ArcGIS Enterprise on Windows.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directury must be set to the arcgis-enterprise-base/windows/application module path
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
 * | /arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket | S3 bucket for the portal content |
 * | /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | SNS topic ARN of the monitoring subsystem |
 * | /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
 * | /arcgis/${var.site_id}/cookbooks-url | Chef cookbooks URL |
 * | /arcgis/${var.site_id}/s3/backup | S3 bucket for the backup |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM command output | 
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket for the private repository |
 */

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

data "aws_ssm_parameter" "chef_client_url" {
  name  = "/arcgis/${var.site_id}/chef-client-url/${var.os}"
}

data "aws_ssm_parameter" "chef_cookbooks_url" {
  name  = "/arcgis/${var.site_id}/cookbooks-url"
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.site_id}/s3/repository"
}

data "aws_ssm_parameter" "s3_backup" {
  name = "/arcgis/${var.site_id}/s3/backup"
}

data "aws_ssm_parameter" "s3_content" {
  name = "/arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket"
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

# Retrieve attributes of standby EC2 instance
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

# Retrieve attributes of primary EC2 instance AMI
data "aws_ami" "primary" {
  filter {
    name   = "image-id"
    values = [data.aws_instance.primary.ami]
  }
}

data "aws_region" "current" {}

locals {
  index_file_path               = "../manifests/arcgis-enterprise-s3files-${var.arcgis_version}.json"
  authorization_files_s3_prefix = "software/authorization/${var.arcgis_version}"
  certificates_s3_prefix        = "software/certificates"

  # fileserver_ip = data.aws_instance.fileserver.private_ip
  fileserver_hostname     = "fileserver.${var.deployment_id}.${var.site_id}.internal"
  primary_hostname        = data.aws_instance.primary.private_ip
  standby_hostname        = data.aws_instance.standby.private_ip
  software_dir            = "C:\\Software\\*"
  authorization_files_dir = "C:\\Software\\AuthorizationFiles"
  certificates_dir        = "C:\\Software\\Certificates"

  keystore_file = var.keystore_file_path != null ? "${local.certificates_dir}\\${basename(var.keystore_file_path)}" : "C:\\chef\\keystore.pfx"
  root_cert     = var.root_cert_file_path != null ? "${local.certificates_dir}\\${basename(var.root_cert_file_path)}" : ""

  # ArcGIS version-specific attributes
  dotnet_setup_path = {
    "11.0" = null
    "11.1" = "C:\\Software\\Archives\\dotnet-hosting-win.exe"
    "11.2" = "C:\\Software\\Archives\\dotnet-hosting-win.exe"
  }

  web_deploy_setup_path = {
    "11.0" = null
    "11.1" = "C:\\Software\\Archives\\WebDeploy_amd64_en-US.msi"
    "11.2" = "C:\\Software\\Archives\\WebDeploy_amd64_en-US.msi"
  }

  timestamp = formatdate("YYYYMMDDHHmmss", timestamp())
}

module "s3_copy_files" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/s3_copy_files"
  bucket_name            = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  index_file             = local.index_file_path
  arcgis_online_username = var.arcgis_online_username
  arcgis_online_password = var.arcgis_online_password
}

# Install Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment
module "bootstrap_deployment" {
  source        = "../../modules/bootstrap"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["fileserver", "primary", "standby"]
  chef_client_url = nonsensitive(data.aws_ssm_parameter.chef_client_url.value)
  chef_cookbooks_url = nonsensitive(data.aws_ssm_parameter.chef_cookbooks_url.value)
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
    local.index_file_path,
    {
      s3bucket = data.aws_ssm_parameter.s3_repository.value
      region   = data.aws_region.current.name
  })
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
    arcgis = {
      version                    = var.arcgis_version
      run_as_user                = var.run_as_user
      run_as_password            = var.run_as_password
      configure_windows_firewall = true
      repository = {
        archives = "C:\\Software\\Archives"
        setups   = "C:\\Software\\Setups"
      }
      server = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\Server"
        install_system_requirements = true
        wa_name                     = "server"
      }
      web_adaptor = {
        install_system_requirements = true
        dotnet_setup_path           = local.dotnet_setup_path[var.arcgis_version]
        web_deploy_setup_path       = local.web_deploy_setup_path[var.arcgis_version]
        admin_access                = true
        reindex_portal_content      = false
      }
      data_store = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\DataStore"
        setup_options               = "ADDLOCAL=relational,tilecache"
        data_dir                    = "C:\\arcgisdatastore"
        install_system_requirements = true
        preferredidentifier         = "ip"
      }
      portal = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\Portal"
        install_system_requirements = true
        data_dir                    = "C:\\arcgisportal"
        wa_name                     = "portal"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-iis::install]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::start_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::install_portal_wa]",
      "recipe[arcgis-enterprise::install_server]",
      "recipe[arcgis-enterprise::start_server]",
      "recipe[arcgis-enterprise::install_server_wa]",
      "recipe[arcgis-enterprise::install_datastore]",
      "recipe[arcgis-enterprise::start_datastore]"
    ]
  })
  execution_timeout = 3600
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
      version = var.arcgis_version
      repository = {
        patches = "C:\\Software\\Archives\\Patches"
      }
      portal = {
        patches = var.arcgis_portal_patches
      }
      server = {
        patches = var.arcgis_server_patches
      }
      data_store = {
        patches = var.arcgis_data_store_patches
      }
      web_adaptor = {
        patches = var.arcgis_web_adaptor_patches
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::install_patches]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_enterprise_upgrade
  ]
}

# Set ArcGISVersion tag on standby EC2 instance after software upgrade is complete
resource "aws_ec2_tag" "standby_arcgis_version" {
  count       = var.is_upgrade ? 1 : 0
  resource_id = data.aws_instance.standby.id
  key         = "ArcGISVersion"
  value       = var.arcgis_version
  depends_on = [
    module.arcgis_enterprise_upgrade
  ]
}

# Set ArcGISVersion tag on primary EC2 instance after software upgrade is complete
resource "aws_ec2_tag" "primary_arcgis_version" {
  count       = var.is_upgrade ? 1 : 0
  resource_id = data.aws_instance.primary.id
  key         = "ArcGISVersion"
  value       = var.arcgis_version
  depends_on = [
    module.arcgis_enterprise_upgrade
  ]
}

# Configure fileserver EC2 instance
module "arcgis_enterprise_fileserver" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/${var.arcgis_version}/fileserver"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["fileserver"]
  json_attributes = jsonencode({
    arcgis = {
      version         = var.arcgis_version
      run_as_user     = var.run_as_user
      run_as_password = var.run_as_password
      fileserver = {
        directories = [
          "C:\\data\\arcgisserver",
          "C:\\data\\arcgisbackup\\webgisdr",
          "C:\\data\\arcgisbackup\\tilecache",
          "C:\\data\\arcgisbackup\\relational"
        ]
        shares = [
          "C:\\data\\arcgisbackup",
          "C:\\data\\arcgisserver"
        ]
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::disable_loopback_check]",
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
  bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  key    = "${local.authorization_files_s3_prefix}/${basename(var.server_authorization_file_path)}"
  source = var.server_authorization_file_path
}

# Upload Portal for ArcGIS authorization file to the private repository S3 bucket
resource "aws_s3_object" "portal_authorization_file" {
  bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  key    = "${local.authorization_files_s3_prefix}/${basename(var.portal_authorization_file_path)}"
  source = var.portal_authorization_file_path
}

# If specified, upload keystore file to the private repository S3 bucket
resource "aws_s3_object" "keystore_file" {
  count  = var.keystore_file_path != null ? 1 : 0
  bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  key    = "${local.certificates_s3_prefix}/${basename(var.keystore_file_path)}"
  source = var.keystore_file_path
}

# If specified, upload root certificate file to the private repository S3 bucket
resource "aws_s3_object" "root_cert_file" {
  count  = var.root_cert_file_path != null ? 1 : 0
  bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
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
      version = var.arcgis_version
      repository = {
        local_archives = local.authorization_files_dir
        server = {
          s3bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
          region   = data.aws_region.current.name
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
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        server = {
          s3bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
          region   = data.aws_region.current.name
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
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        server = {
          s3bucket = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
          region   = data.aws_region.current.name
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
    arcgis = {
      version                    = var.arcgis_version
      run_as_user                = var.run_as_user
      run_as_password            = var.run_as_password
      configure_windows_firewall = true
      hosts = {
        "${var.deployment_fqdn}" = ""
      }
      repository = {
        archives = "C:\\Software\\Archives"
        setups   = "C:\\Software\\Setups"
      }
      iis = {
        domain_name           = var.deployment_fqdn
        keystore_file         = local.keystore_file
        keystore_password     = var.keystore_file_password
        replace_https_binding = true
      }
      server = {
        install_dir                    = "C:\\Program Files\\ArcGIS\\Server"
        install_system_requirements    = true
        private_url                    = "https://${var.deployment_fqdn}:6443/arcgis"
        web_context_url                = "https://${var.deployment_fqdn}/server"
        hostname                       = local.primary_hostname
        admin_username                 = var.admin_username
        admin_password                 = var.admin_password
        authorization_file             = "${local.authorization_files_dir}\\${basename(var.server_authorization_file_path)}"
        keystore_file                  = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password              = var.keystore_file_password
        root_cert                      = local.root_cert
        root_cert_alias                = "rootcert"
        directories_root               = "\\\\${local.fileserver_hostname}\\arcgisserver"
        log_dir                        = "C:\\arcgisserver\\logs"
        log_level                      = var.log_level
        config_store_type              = "FILESYSTEM"
        config_store_connection_string = "\\\\${local.fileserver_hostname}\\arcgisserver\\config-store"
        wa_name                        = "server"
        services_dir_enabled           = true
        system_properties = {
          WebContextURL = "https://${var.deployment_fqdn}/server"
        }
      }
      data_store = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\DataStore"
        setup_options               = "ADDLOCAL=relational,tilecache"
        install_system_requirements = true
        data_dir                    = "C:\\arcgisdatastore"
        preferredidentifier         = "ip"
        types                       = "tileCache,relational"
        tilecache = {
          backup_type     = "s3"
          backup_location = "type=s3;location=${nonsensitive(data.aws_ssm_parameter.s3_backup.value)}/tilecache-${local.timestamp};name=tc_default;region=${data.aws_region.current.name}"
        }
        relational = {
          backup_type     = "s3"
          backup_location = "type=s3;location=${nonsensitive(data.aws_ssm_parameter.s3_backup.value)}/relational-${local.timestamp};name=re_default;region=${data.aws_region.current.name}"
        }
        # tilecache = {
        #   backup_type     = "fs"
        #   backup_location = "\\\\${local.fileserver_hostname}\\arcgisbackup\\tilecache"
        # }
        # relational = {
        #   backup_type     = "fs"
        #   backup_location = "\\\\${local.fileserver_hostname}\\arcgisbackup\\relational"
        # }
      }
      portal = {
        hostname                    = local.primary_hostname
        hostidentifier              = local.primary_hostname
        install_dir                 = "C:\\Program Files\\ArcGIS\\Portal"
        install_system_requirements = true
        private_url                 = "https://${var.deployment_fqdn}:7443/arcgis"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        admin_email                 = var.admin_email
        admin_full_name             = var.admin_full_name
        admin_description           = var.admin_description
        security_question           = var.security_question
        security_question_answer    = var.security_question_answer
        data_dir                    = "C:\\arcgisportal"
        log_dir                     = "C:\\arcgisportal\\logs"
        log_level                   = var.log_level
        content_store_type          = "CloudStore"
        content_store_provider      = "Amazon"
        content_store_connection_string = {
          region         = data.aws_region.current.name
          credentialType = "IAMRole"
        }
        object_store         = data.aws_ssm_parameter.s3_content.value
        authorization_file   = "${local.authorization_files_dir}\\${basename(var.portal_authorization_file_path)}"
        user_license_type_id = var.portal_user_license_type_id
        keystore_file        = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password    = var.keystore_file_password
        root_cert            = local.root_cert
        root_cert_alias      = "rootcert"
        wa_name              = "portal"
        system_properties = {
          privatePortalURL = "https://${var.deployment_fqdn}:7443/arcgis"
          WebContextURL    = "https://${var.deployment_fqdn}/portal"
        }
      }
      web_adaptor = {
        install_system_requirements = true
        dotnet_setup_path           = null
        web_deploy_setup_path       = null
        admin_access                = true
        reindex_portal_content      = false
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::disable_loopback_check]",
      "recipe[esri-iis]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal]",
      "recipe[arcgis-enterprise::portal_wa]",
      "recipe[arcgis-enterprise::server]",
      "recipe[arcgis-enterprise::server_wa]",
      "recipe[arcgis-enterprise::datastore]",
      "recipe[arcgis-enterprise::federation]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.authorization_files,
    module.keystore_file,
    module.root_cert
  ]
}

# Configure base ArcGIS Enterprise on stanby EC2 instance
module "arcgis_enterprise_standby" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/standby"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                    = var.arcgis_version
      run_as_user                = var.run_as_user
      run_as_password            = var.run_as_password
      configure_windows_firewall = true
      hosts = {
        "${var.deployment_fqdn}" = ""
      }
      repository = {
        archives = "C:\\Software\\Archives"
        setups   = "C:\\Software\\Setups"
      }
      iis = {
        domain_name           = var.deployment_fqdn
        keystore_file         = local.keystore_file
        keystore_password     = var.keystore_file_password
        replace_https_binding = true
      }
      server = {
        hostname                    = local.standby_hostname
        install_dir                 = "C:\\Program Files\\ArcGIS\\Server"
        install_system_requirements = true
        primary_server_url          = "https://${local.primary_hostname}/server"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        authorization_file          = "${local.authorization_files_dir}\\${basename(var.server_authorization_file_path)}"
        keystore_file               = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        log_dir                     = "C:\\arcgisserver\\logs"
        wa_name                     = "server"
      }
      data_store = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\DataStore"
        setup_options               = "ADDLOCAL=relational,tilecache"
        install_system_requirements = true
        data_dir                    = "C:\\arcgisdatastore"
        preferredidentifier         = "ip"
        types                       = "tileCache,relational"
      }
      portal = {
        hostname                    = local.standby_hostname
        hostidentifier              = local.standby_hostname
        install_dir                 = "C:\\Program Files\\ArcGIS\\Portal"
        install_system_requirements = true
        primary_machine_url         = "https://${local.primary_hostname}:7443"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        keystore_file               = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        data_dir                    = "C:\\arcgisportal"
        log_dir                     = "C:\\arcgisportal\\logs"
        wa_name                     = "portal"
      }
      web_adaptor = {
        install_system_requirements = true
        dotnet_setup_path           = null
        web_deploy_setup_path       = null
        admin_access                = true
        reindex_portal_content      = false
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::disable_loopback_check]",
      "recipe[esri-iis]",
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

# Delete the downloaded setup archives, the extracted setups and other 
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
