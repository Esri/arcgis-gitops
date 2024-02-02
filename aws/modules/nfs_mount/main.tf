/*
 * # Terraform module nfs_mount
 * 
 * Terraform module nfs_mount mounts an NFS target on EC2 instances in a deployment.
 *
 * The module uses ssm_nfs_mount.py script to run {var.site-id}-nfs-mount SSM command on the deployment's EC2 instances in specific roles.
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

resource "null_resource" "nfs_mount" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    command = "python -m ssm_nfs_mount -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -a ${var.file_system_dns} -p ${var.mount_point} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)}"
  }
}
