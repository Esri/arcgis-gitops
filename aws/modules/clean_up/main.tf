/*
 * # Terraform module clean_up
 * 
 * Terraform module deletes files in specific directories on EC2 instances in specific roles. 
 * Optionally, if the uninstall_chef_client variable is set to true, the module also uninstalls Chef client on the instances. 
 *
 * The module uses ssm_clean_up.py script to run {var.site-id}-clean-up SSM command on the deployment's EC2 instances in specific roles.
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

resource "null_resource" "clean_up" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    command = "python -m ssm_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -f ${join(",", var.directories)} -u ${var.uninstall_chef_client ? "true" : "false"} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)}"
  }
}
