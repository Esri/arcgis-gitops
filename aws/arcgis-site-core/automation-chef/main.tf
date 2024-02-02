/**
 * # Terraform module automation-chef
 *
 * The module provisions AWS resources required for ArcGIS Enterprise site configuration management 
 * using IT automation tool Chef/Cinc:
 *
 * * Looks up the latest AMIs for the supported operating systems
 * * Copies Chef/Cinc client setups and Chef cookbooks for ArcGIS distribution archive from the URLs specified
 * in [automation-chef-files.json](../config/automation-chef-files.json) file to the private repository S3 bucket
 * * Creates SSM documents for the ArcGIS Enterprise site
 * 
 * The AMI IDs for each operating system as well as S3 URLs are stored in SSM parameters:
 *
 * | SSM parameter name | Description |
 * | --- | --- |
 * | /arcgis/${var.site_id}/images/${os} | Ids of the latest AMI for the operating systems |
 * | /arcgis/${var.site_id}/chef-client-url/${os} | S3 URLs of Cinc Client setup for the operating systems |
 * | /arcgis/${var.site_id}/cookbooks-url | S3 URL of Chef cookbooks for ArcGIS distribution archive |
 *
 * SSM documents created by the module:
 * 
 * | SSM document name | Description |
 * | --- | --- |
 * | ${var.site_id}-bootstrap | Installs Chef/Cinc Client and Chef Cookbooks for ArcGIS on EC2 instances |
 * | ${var.site_id}-clean-up | Deletes temporary files created by Chef runs |
 * | ${var.site_id}-install-awscli | Installs AWS CLI on EC2 instances |
 * | ${var.site_id}-nfs-mount | Mounts NFS target on EC2 instances |
 * | ${var.site_id}-run-chef | Runs Chef in solo ode with specified JSON attributes |
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the automation-chef module path (because [automation-chef-files.json](../config/automation-chef-files.json) uses relative path to the Chef cookbooks archive)
 * * AWS credentials must be configured.
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable.
 *
 * Before using the module, the repository S3 bucket must be created by infrastructure-core terraform module.
 */

 terraform {
  backend "s3" {
    key = "arcgis-enterprise/aws/automation-chef.tfstate"
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
      ArcGISSiteId = var.site_id
    }
  }
}

data "aws_ssm_parameter" "s3_repository" {
  name = "/arcgis/${var.site_id}/s3/repository"
}

# Look up the latest AMIs for the supported OSs

data "aws_ami" "os_image" {
  for_each = var.images

  most_recent = true

  filter {
    name   = "name"
    values = [var.images[each.key].ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.images[each.key].owner]
}

# Copy Chef automation tools to S3

module "s3_copy_files" {
  source = "../../modules/s3_copy_files"
  bucket_name = nonsensitive(data.aws_ssm_parameter.s3_repository.value)
  index_file = "../config/automation-chef-files.json"
}

# Create/update SSM documents

resource "aws_ssm_document" "install_awscli_command" {
  name          = "${var.site_id}-install-awscli"
  document_type = "Command"
  content = file("${path.module}/commands/install-awscli.json")
}

resource "aws_ssm_document" "nfs_mount_command" {
  name          = "${var.site_id}-nfs-mount"
  document_type = "Command"
  content = file("${path.module}/commands/nfs-mount.json")
}

resource "aws_ssm_document" "bootstrap_command" {
  name          = "${var.site_id}-bootstrap"
  document_type = "Command"
  content = replace(replace(
    file("${path.module}/commands/bootstrap.json"), 
    "{{ssm:/arcgis/arcgis-enterprise/chef-client-url/windows2022}}",
    "{{ssm:/arcgis/${var.site_id}/chef-client-url/windows2022}}"),
    "{{ssm:/arcgis/arcgis-enterprise/cookbooks-url}}",
    "{{ssm:/arcgis/${var.site_id}/cookbooks-url}}")
}

resource "aws_ssm_document" "run_chef_command" {
  name          = "${var.site_id}-run-chef"
  document_type = "Command"
  content = file("${path.module}/commands/run-chef.json")
}

resource "aws_ssm_document" "clean_up_command" {
  name          = "${var.site_id}-clean-up"
  document_type = "Command"
  content = file("${path.module}/commands/clean-up.json")
}

# AMIs

resource "aws_ssm_parameter" "images_parameters" {
  for_each = data.aws_ami.os_image
  name  = "/arcgis/${var.site_id}/images/${each.key}"
  type  = "String"
  value = each.value.id
  description = each.value.description
}

# Chef client

resource "aws_ssm_parameter" "chef_client_urls" {
  for_each = var.chef_client_paths
  name  = "/arcgis/${var.site_id}/chef-client-url/${each.key}"
  type  = "String"
  value = nonsensitive("s3://${data.aws_ssm_parameter.s3_repository.value}/${var.chef_client_paths[each.key].path}")
  description = var.chef_client_paths[each.key].description
}

resource "aws_ssm_parameter" "chef_client_log_level" {
  name  = "/chef/log_level"
  type  = "String"
  value = "info"
  description = "Chef/Cinc client log level"
}

# Chef Cookbooks

resource "aws_ssm_parameter" "arcgis_cookbooks_url" {
  name  = "/arcgis/${var.site_id}/cookbooks-url"
  type  = "String"
  value = nonsensitive("s3://${data.aws_ssm_parameter.s3_repository.value}/${var.arcgis_cookbooks_path}")
  description = "Chef cookbooks for ArcGIS distribution archive S3 URL"
}
