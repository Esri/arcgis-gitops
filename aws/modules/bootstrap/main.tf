/*
 * # Terraform module bootstrap
 * 
 * Terraform module installs or upgrades Chef client and Chef Cookbooks for ArcGIS on EC2 instances.
 *
 * The module uses ssm_bootstrap.py script to run {var.site-id}-bootstrap SSM command on the deployment's EC2 instances in specific roles.
 *
 * ## Requirements
 *
 * The S3 bucket for the SSM command output is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable
 */

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }
}

data "aws_ssm_parameter" "output_s3_bucket" {
  name  = "/arcgis/${var.site_id}/s3/logs"
}

resource "null_resource" "bootstrap" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "python -m ssm_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -c ${var.chef_client_url} -k ${var.chef_cookbooks_url} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)}"
  }
}
