/**
 * # Terraform module run_chef
 * 
 * Terraform module run_chef runs Cinc client in zero mode on EC2 instances in specified roles.
 * 
 * The module runs ssm_run_chef.py python script that creates a SecureString SSM parameter with Chef JSON attributes and
 * runs {var.site-id}-run-chef SSM command on the deployment's EC2 instances in specific roles.
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
 *
 *  Cinc client and Chef Cookbooks for ArcGIS must be installed on the target EC2 instances.
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

resource "null_resource" "run_chef" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    environment = {
      JSON_ATTRIBUTES = nonsensitive(base64encode(var.json_attributes))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -j ${var.parameter_name} -b ${nonsensitive(data.aws_ssm_parameter.output_s3_bucket.value)} -e ${var.execution_timeout}"
  }
}
