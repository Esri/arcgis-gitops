/**
 * # Restore Terraform Module for ArcGIS Server on Linux
 *
 * The Terraform module retrieves the last a backup from S3 bucket and restores ArcGIS Server deployment from the backup.
 *
 * The module runs 'restore' admin utility on the primary EC2 instance of the deployment.
 *
 * ## Requirements
 *
 * The ArcGIS Server must be configured on the deployment by application terraform module for ArcGIS Server on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Ansible 2.16 or later must be installed
 * * arcgis.common and arcgis.server Ansible collections must be installed
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 *
 * The module retrieves the backup S3 bucket name from '/arcgis/${var.site_id}/s3/backup' SSM parameters.
 */

terraform {
  backend "s3" {
    key = "terraform/arcgis-enterprise/arcgis-server/restore.tfstate"
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


# Restore ArcGIS Server configurtion from backup
module "arcgis_server_restore" {
  source         = "../../modules/ansible_playbook"
  site_id        = var.site_id
  deployment_id  = var.deployment_id
  machine_roles  = ["primary"]
  playbook       = "arcgis.server.s3_restore"
  external_vars  = {
    server_url = "https://localhost:6443/arcgis"
    admin_username = var.admin_username
    admin_password = var.admin_password
    install_dir = "/opt"
    run_as_user = var.run_as_user
    s3_bucket = data.aws_ssm_parameter.s3_backup.value
    s3_region = data.aws_region.current.name  
    s3_prefix = var.s3_prefix
  }
}
