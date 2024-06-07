/**
 * # Terraform module ansible_playbook
 * 
 * Terraform module runs Ansible playbooks on the deployment's EC2 instances in specific roles.
 * 
 * The module uses community.aws.aws_ssm connection plugin to connect to EC2 instances via AWS Systems Manager.
 *
 * ## Requirements
 *
 * The name of the S3 bucket used by the SSM connection for file transfers is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Ansible must be installed
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

data "aws_region" "current" {}

data "aws_ssm_parameter" "ansible_aws_ssm_bucket" {
  name  = "/arcgis/${var.site_id}/s3/logs"
}

locals {
  session_id = uuid()
}
resource "local_sensitive_file" "external_vars" {
  content = yamlencode(merge(
    var.external_vars,
    {
      ansible_connection = "aws_ssm"
      ansible_aws_ssm_bucket_name = data.aws_ssm_parameter.ansible_aws_ssm_bucket.value
      ansible_aws_ssm_region = data.aws_region.current.name
      ansible_python_interpreter = "/usr/bin/python3"
    })
  )
  filename = "/tmp/${local.session_id}/external_vars.yaml"
}

resource "local_file" "inventory" {
  content  = yamlencode({
    plugin = "amazon.aws.aws_ec2"
    regions = [ 
      data.aws_region.current.name
    ]
    compose = {
      ansible_host = "instance_id"
    }
    filters = {
      "instance-state-name" = "running"
      "tag:ArcGISSiteId" = var.site_id
      "tag:ArcGISDeploymentId" = var.deployment_id
      "tag:ArcGISMachineRole" = var.machine_roles
    }
  })
  filename = "/tmp/${local.session_id}/inventory.aws_ec2.yaml"
}

resource "null_resource" "ansible_playbook" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    command = "ansible-playbook ${var.playbook} -i ${local_file.inventory.filename} -e @${local_sensitive_file.external_vars.filename}"
  }
}
