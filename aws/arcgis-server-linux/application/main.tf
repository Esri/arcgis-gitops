/**
 * # Application Terraform Module for ArcGIS Server on Linux
 *
 * The Terraform module configures or upgrades applications for an ArcGIS Server deployment on the Linux platforms.
 *
 * ![ArcGIS Server on Linux](arcgis-server-linux-application.png "ArcGIS Server on Linux")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment.
 *
 * If is_upgrade input variable is set to true, the module:
 *
 * * Copies the installation media for the ArcGIS Server version specified by arcgis_version input variable to the private repository S3 bucket
 * * Downloads the installation media from the private repository S3 bucket to primary and node EC2 instances
 * * Upgrades OpenJDK, Apache Tomcat, ArcGIS Server, and ArcGIS Web Adaptor on primary and node EC2 instances
 * * Installs ArcGIS Server patches on primary and node EC2 instances
 *
 * Then the module:
 *
 * * Creates the required directories in the NFS mount
 * * Copies the ArcGIS Server authorization file to the EC2 instances
 * * Configures ArcGIS Server and ArcGIS Web Adaptor on primary EC2 instance
 * * Configures ArcGIS Server and ArcGIS Web Adaptor on node EC2 instances
 * * If server_role input variable is specified, federates ArcGIS Server with Portal for ArcGIS
 *
 * Starting with ArcGIS Server 12.0, if the config_store_type input variable is set to AMAZON,
 * the module configures ArcGIS Server to store server directories in an S3 bucket and 
 * the configuration store in a DynamoDB table, rather than on the EFS file system.
 *
 * ## Requirements
 *
 * The AWS resources for the deployment must be provisioned by Infrastructure terraform module for ArcGIS Server on Linux.
 *
 * On the machine where Terraform is executed:
 * 
* * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the arcgis-server-linux/application module path
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
 * | /arcgis/${var.enterprise_id}/${var.deployment_id}/backup/plan-id | Backup plan ID for the deployment |
 * | /arcgis/${var.enterprise_id}/${var.deployment_id}/ingress-fqdn | Fully qualified domain name of the ingress |
 * | /arcgis/${var.enterprise_id}/${var.deployment_id}/namespace | Namespace of the deployment used to generate unique resource names |
 * | /arcgis/${var.enterprise_id}/${var.deployment_id}/object-store-s3-bucket | S3 bucket for the object store |
 * | /arcgis/${var.enterprise_id}/${var.deployment_id}/portal-url | Portal for ArcGIS URL (if server_role input variable is specified) | 
 * | /arcgis/${var.enterprise_id}/chef-client-url/${os} | Chef Client URL for the operating system |
 * | /arcgis/${var.enterprise_id}/cookbooks-url | Chef cookbooks URL |
 * | /arcgis/${var.enterprise_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |
 * | /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system identifier |
 * | /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context | ArcGIS Server web context | 
 * | /arcgis/${var.enterprise_id}/s3/backup | S3 bucket for the backup |
 * | /arcgis/${var.enterprise_id}/s3/logs | S3 bucket for SSM command output |
 * | /arcgis/${var.enterprise_id}/s3/repository | S3 bucket for the private repository |
 * | /arcgis/${var.enterprise_id}/vpc/hosted-zone-id | VPC hosted zone ID |
 * | /arcgis/${var.enterprise_id}/vpc/id | VPC ID |
 * | /arcgis/${var.enterprise_id}/vpc/subnets | IDs of VPC subnets |
 */

# Copyright 2024-2026 Esri
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
    key = "terraform/arcgis/arcgis-server-linux/application.tfstate"
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
      ArcGISEnterpriseID = var.enterprise_id
      ArcGISDeploymentID = var.deployment_id
    }
  }

  ignore_tags {
    keys = ["ArcGISVersion"]
  }
}

data "aws_ssm_parameter" "ingress_fqdn" {
  name = "/arcgis/${var.enterprise_id}/${var.deployment_id}/ingress-fqdn"
}

data "aws_ssm_parameter" "namespace" {
  name = "/arcgis/${var.enterprise_id}/${var.deployment_id}/namespace"
}

data "aws_ssm_parameter" "object_store" {
  name = "/arcgis/${var.enterprise_id}/${var.deployment_id}/object-store-s3-bucket"
}

data "aws_ssm_parameter" "os" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/os"
}

data "aws_ssm_parameter" "portal_url" {
  count = var.server_role != "" ? 1 : 0
  name  = "/arcgis/${var.enterprise_id}/${var.deployment_id}/portal-url"
}

data "aws_ssm_parameter" "server_web_context" {
  name = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context"
}

# Retrieve attributes of the primary EC2 instance
data "aws_instance" "primary" {
  filter {
    name   = "tag:ArcGISEnterpriseID"
    values = [var.enterprise_id]
  }

  filter {
    name   = "tag:ArcGISDeploymentID"
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
    name   = "tag:ArcGISEnterpriseID"
    values = [var.enterprise_id]
  }

  filter {
    name   = "tag:ArcGISDeploymentID"
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
  archives_dir            = local.server_manifest.arcgis.repository.local_archives
  patches_dir             = local.server_manifest.arcgis.repository.local_patches
  authorization_files_dir = "/opt/software/authorization"
  certificates_dir        = "/opt/software/certificates"
  software_dir            = "/opt/software/*"

  ingress_fqdn     = nonsensitive(data.aws_ssm_parameter.ingress_fqdn.value)
  keystore_file    = var.server_certificate_path != null ? "${local.certificates_dir}/${basename(var.server_certificate_path)}" : ""
  root_cert        = var.root_certificate_path != null ? "${local.certificates_dir}/${basename(var.root_certificate_path)}" : ""
  mount_point      = "/mnt/efs"
  namespace        = nonsensitive(data.aws_ssm_parameter.namespace.value)
  os               = nonsensitive(data.aws_ssm_parameter.os.value)
  primary_hostname = data.aws_instance.primary.private_ip

  server_manifest    = jsondecode(file(local.manifest_file_path))
  manifest_file_path = "${abspath(path.root)}/../manifests/arcgis-server-s3files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  java_tarball       = local.manifest.arcgis.repository.metadata.java_tarball
  java_version       = local.manifest.arcgis.repository.metadata.java_version
  tomcat_tarball     = local.manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version     = local.manifest.arcgis.repository.metadata.tomcat_version

  authorization_files_s3_prefix = "software/authorization/${var.arcgis_version}"
  certificates_s3_prefix        = "software/certificates"

  server_web_context = nonsensitive(data.aws_ssm_parameter.server_web_context.value)
  portal_url         = var.server_role != "" ? nonsensitive(data.aws_ssm_parameter.portal_url[0].value) : ""

  cloud_config = var.config_store_type == "AMAZON" ? jsonencode([
    {
      name      = "AWS"
      namespace = local.namespace
      region    = data.aws_region.current.id
      credential = {
        type = "IAM-ROLE"
      }
      cloudServices = [{
        type     = "objectStore"
        name     = "AWS S3"
        category = "storage"
        connection = {
          bucketName        = nonsensitive(data.aws_ssm_parameter.object_store.value)
          regionEndpointUrl = "https://s3.${data.aws_region.current.id}.amazonaws.com"
          rootDir           = "arcgis"
        }
        }, {
        type     = "tableStore"
        name     = "Amazon Dynamo DB"
        category = "storage"
        connection = {
          regionEndpointUrl = "https://dynamodb.${data.aws_region.current.id}.amazonaws.com"
        }
        }, {
        type     = "queueService"
        name     = "Amazon Queue Service"
        category = "queue"
        connection = {
          regionEndpointUrl = "https://sqs.${data.aws_region.current.id}.amazonaws.com"
        }
      }]
      cloudServiceTags = [{
        ArcGISEnterpriseID = var.enterprise_id
        }, {
        ArcGISDeploymentID = var.deployment_id
        }, {
        ArcGISRole = "config-store"
      }]
    }]
  ) : null
}

module "enterprise_core_info" {
  source        = "../../modules/enterprise_core_info"
  enterprise_id = var.enterprise_id
}

# Copy ArcGIS Server setup archives to the private repository S3 bucket
module "copy_server_files" {
  count       = var.is_upgrade ? 1 : 0
  source      = "../../modules/s3_copy_files"
  bucket_name = module.enterprise_core_info.s3_repository
  index_file  = local.manifest_file_path
}

# Install Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment
module "bootstrap_deployment" {
  source           = "../../modules/bootstrap"
  os               = local.os
  enterprise_id    = var.enterprise_id
  deployment_id    = var.deployment_id
  machine_roles    = ["primary", "node"]
  output_s3_bucket = module.enterprise_core_info.s3_logs
}

# Download ArcGIS Server setup archives from the private repository S3 bucket
# to /opt/software/archives directory on primary and node EC2 instances.
module "arcgis_server_files" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/files"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = templatefile(
    local.manifest_file_path,
    {
      s3bucket = module.enterprise_core_info.s3_repository
      region   = module.enterprise_core_info.s3_region
    }
  )
  execution_timeout = 1800
  depends_on = [
    module.bootstrap_deployment,
    module.copy_server_files
  ]
}

# If it's an upgrade, unregister ArcGIS Server's Web Adaptor on node EC2 instance
module "begin_upgrade_nodes" {
  count          = var.is_upgrade && length(data.aws_instances.nodes.ids) > 0 ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/begin-upgrade-nodes"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["node"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
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
    module.arcgis_server_files
  ]
}

# Upgrade ArcGIS Server on primary and node EC2 instances
module "arcgis_server_upgrade" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/upgrade"
  enterprise_id  = var.enterprise_id
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
        wa_name                     = local.server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat::openjdk]",
      "recipe[esri-tomcat]",
      "recipe[arcgis-enterprise::stop_server]",
      "recipe[arcgis-enterprise::install_server]",
      "recipe[arcgis-enterprise::start_server]",
      "recipe[arcgis-enterprise::install_server_wa]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_server_files,
    module.begin_upgrade_nodes
  ]
}

# Install ArcGIS Server patches on primary and node EC2 instances
module "arcgis_server_patch" {
  count          = var.is_upgrade ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/patch"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        patches = local.patches_dir
      }
      server = {
        install_dir = "/opt"
        patches     = var.arcgis_server_patches
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
    module.arcgis_server_upgrade
  ]
}

# Configure EFS fileserver
module "arcgis_server_fileserver" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/${var.arcgis_version}/fileserver"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      fileserver = {
        directories = [
          "${local.mount_point}/${local.namespace}/arcgisserver"
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
    module.arcgis_server_patch
  ]
}

# Upload ArcGIS Server authorization file to the private repository S3 bucket
resource "aws_s3_object" "server_authorization_file" {
  bucket = module.enterprise_core_info.s3_repository
  key    = "${local.authorization_files_s3_prefix}/${basename(var.server_authorization_file_path)}"
  source = var.server_authorization_file_path
}

# If specified, upload keystore file to the private repository S3 bucket
resource "aws_s3_object" "keystore_file" {
  count  = var.server_certificate_path != null ? 1 : 0
  bucket = module.enterprise_core_info.s3_repository
  key    = "${local.certificates_s3_prefix}/${basename(var.server_certificate_path)}"
  source = var.server_certificate_path
}

# If specified, upload root certificate file to the private repository S3 bucket
resource "aws_s3_object" "root_cert_file" {
  count  = var.root_certificate_path != null ? 1 : 0
  bucket = module.enterprise_core_info.s3_repository
  key    = "${local.certificates_s3_prefix}/${basename(var.root_certificate_path)}"
  source = var.root_certificate_path
}

# Copy ArcGIS Server authorization file to primary and node EC2 instances
module "authorization_file" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/authorization-file"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.authorization_files_dir
        server = {
          s3bucket = module.enterprise_core_info.s3_repository
          region   = module.enterprise_core_info.s3_region
        }
        files = {
          "${basename(var.server_authorization_file_path)}" = {
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
    module.arcgis_server_fileserver,
    aws_s3_object.server_authorization_file
  ]
}

# Copy keystore file to primary and node EC2 instances
module "keystore_file" {
  count          = var.server_certificate_path != null ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/keystore-file"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        server = {
          s3bucket = module.enterprise_core_info.s3_repository
          region   = module.enterprise_core_info.s3_region
        }
        files = {
          "${basename(var.server_certificate_path)}" = {
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
    module.authorization_file,
    aws_s3_object.keystore_file
  ]
}

# Download root certificate file to primary and node EC2 instances
module "root_cert" {
  count          = var.root_certificate_path != null ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/root-cert"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        server = {
          s3bucket = module.enterprise_core_info.s3_repository
          region   = module.enterprise_core_info.s3_region
        }
        files = {
          "${basename(var.root_certificate_path)}" = {
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
    module.authorization_file,
    module.keystore_file,
    aws_s3_object.root_cert_file
  ]
}

# Authorize ArcGIS Server on primary machine, create an ArcGIS Server site,
# set the site's system properties, and configure SSL certificates of the machine.
module "arcgis_server_primary" {
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/primary"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = local.ingress_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = var.server_certificate_password
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
        url                   = "https://${local.primary_hostname}:6443/arcgis"
        wa_url                = "https://${local.primary_hostname}/${local.server_web_context}"
        install_dir           = "/opt"
        private_url           = "https://${local.ingress_fqdn}/${local.server_web_context}"
        web_context_url       = "https://${local.ingress_fqdn}/${local.server_web_context}"
        hostname              = local.primary_hostname
        admin_username        = var.admin_username
        admin_password        = var.admin_password
        authorization_file    = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
        authorization_options = var.server_authorization_options
        keystore_file         = local.keystore_file
        keystore_password     = var.server_certificate_password
        root_cert             = local.root_cert
        root_cert_alias       = "rootcert"
        directories_root      = "${local.mount_point}/${local.namespace}/arcgisserver"
        log_dir               = "/opt/arcgis/server/usr/logs"
        log_level             = var.log_level
        config_store_type     = var.config_store_type
        # If cloud_config is set, config_store_connection_string is ignored
        config_store_connection_string = "${local.mount_point}/${local.namespace}/arcgisserver/config-store"
        cloud_config                   = local.cloud_config
        install_system_requirements    = true
        wa_name                        = local.server_web_context
        services_dir_enabled           = var.services_dir_enabled
        callback_functions_enabled     = true
        system_properties              = var.system_properties
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
      "recipe[arcgis-enterprise::server]",
      "recipe[arcgis-enterprise::server_wa]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_server_fileserver,
    module.authorization_file,
    module.keystore_file,
    module.root_cert
  ]
}

# Authorize ArcGIS Server on the node machines, join the machines to
# an existing ArcGIS Server site, and configure SSL certificates of the machines.
module "arcgis_server_node" {
  count          = length(data.aws_instances.nodes.ids) > 0 ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/node"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["node"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = local.ingress_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = var.server_certificate_password
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
      server = {
        install_dir                 = "/opt"
        primary_server_url          = "https://${local.primary_hostname}:6443/arcgis"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        log_dir                     = "${local.mount_point}/${local.namespace}/arcgisserver/logs"
        authorization_file          = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
        authorization_options       = var.server_authorization_options
        install_system_requirements = true
        wa_name                     = local.server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat]",
      "recipe[arcgis-enterprise::server_node]",
      "recipe[arcgis-enterprise::server_wa]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_server_primary
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
  enterprise_id      = var.enterprise_id

  depends_on = [
    module.arcgis_server_primary
  ]
}

# Federate ArcGIS Server with Portal for ArcGIS
module "arcgis_server_federation" {
  count          = var.server_role != "" ? 1 : 0
  source         = "../../modules/run_chef"
  parameter_name = "/arcgis/${var.enterprise_id}/attributes/${var.deployment_id}/arcgis-server/federation"
  enterprise_id  = var.enterprise_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      portal = {
        private_url     = local.portal_url
        admin_username  = var.portal_username
        admin_password  = var.portal_password
        root_cert       = ""
        root_cert_alias = "server"
      }
      server = {
        web_context_url = "https://${local.ingress_fqdn}/${local.server_web_context}"
        private_url     = "https://${local.ingress_fqdn}/${local.server_web_context}"
        admin_username  = var.admin_username
        admin_password  = var.admin_password
        is_hosting      = false
      }
    }
    run_list = concat(
      ["recipe[arcgis-enterprise::federation]"],
      contains(var.server_functions, "RasterAnalytics") ? ["recipe[arcgis-enterprise::enable_rasteranalytics]"] : [],
      contains(var.server_functions, "ImageHosting") ? ["recipe[arcgis-enterprise::enable_imagehosting]"] : [],
      contains(var.server_functions, "KnowledgeServer") ? ["recipe[arcgis-enterprise::enable_knowledgeserver]"] : []
    )
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_server_primary,
    module.arcgis_server_node
  ]
}

# Delete the downloaded setup archives, the extracted setups, and other 
# temporary files from primary and node EC2 instances.
module "clean_up" {
  source                = "../../modules/clean_up"
  enterprise_id         = var.enterprise_id
  deployment_id         = var.deployment_id
  machine_roles         = ["primary", "node"]
  directories           = [local.software_dir]
  uninstall_chef_client = false
  depends_on = [
    module.arcgis_server_federation
  ]
}
