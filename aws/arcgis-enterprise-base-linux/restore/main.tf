/**
 * # Restore Terraform Module for Base ArcGIS Enterprise on Linux
 *
 * The Terraform module restores from backup base ArcGIS Enterprise deployment on Linux platform.
 *
 * The module runs WebGISDR utility with 'import' option on primary EC2 instance of the deployment.
 *
 * ## Requirements
 *
 * The base ArcGIS Enterprise must be configured on the deployment by application terraform module for base ArcGIS Enterprise on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 *
 * ## SSM Parameters
 *
 * The module uses the following SSM parameters: 
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/s3/backup | Backup S3 bucket |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM command output |
 */

terraform {
  backend "s3" {
    key = "terraform/arcgis-enterprise/arcgis-enterprise-base/restore.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }

  required_version = ">= 1.1.9"
}

data "aws_ssm_parameter" "s3_backup" {
  name = "/arcgis/${var.site_id}/s3/backup"
}

data "aws_region" "current" {}

locals {
  shared_location = "/mnt/efs/gisdata/arcgisbackup/webgisdr"
}

# Run webgisdr utility with import option on primary EC2 instance.
module "arcgis_enterprise_webgisdr_import" {
  source            = "../../modules/run_chef"
  parameter_name    = "/arcgis/${var.site_id}/attributes/${var.deployment_id}/arcgis-enterprise-base/webgisdr/import"
  site_id           = var.site_id
  deployment_id     = var.deployment_id
  machine_roles     = ["primary"]
  execution_timeout = var.execution_timeout
  json_attributes = jsonencode({
    arcgis = {
      run_as_user = var.run_as_user
      portal = {
        install_dir      = "/opt"
        webgisdr_timeout = var.execution_timeout
        webgisdr_properties = {
          PORTAL_ADMIN_URL                = var.portal_admin_url
          PORTAL_ADMIN_USERNAME           = var.admin_username
          PORTAL_ADMIN_PASSWORD           = var.admin_password
          PORTAL_ADMIN_PASSWORD_ENCRYPTED = false
          BACKUP_RESTORE_MODE             = var.backup_restore_mode
          SHARED_LOCATION                 = local.shared_location
          INCLUDE_SCENE_TILE_CACHES       = false
          BACKUP_STORE_PROVIDER           = "AmazonS3"
          S3_ENCRYPTED                    = false
          S3_BUCKET                       = nonsensitive(data.aws_ssm_parameter.s3_backup.value)
          S3_CREDENTIALTYPE               = "IAMRole"
          S3_REGION                       = data.aws_region.current.name
          #S3_BACKUP_NAME                 = "<backup file name>"
          PORTAL_BACKUP_S3_BUCKET = nonsensitive(data.aws_ssm_parameter.s3_backup.value)
          PORTAL_BACKUP_S3_REGION = data.aws_region.current.name
        }
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::webgisdr_import]"
    ]
  })
}
