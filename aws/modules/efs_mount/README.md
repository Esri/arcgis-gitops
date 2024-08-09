<!-- BEGIN_TF_DOCS -->
# Terraform module nfs_mount

Terraform module efs_mount mounts EFS file system targets on EC2 instances in a deployment.

The module uses ssm_efs_mount.py script to run {var.site-id}-efs-mount SSM command on the deployment's EC2 instances in specific roles.

## Requirements

The S3 bucket for the SSM command output is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.22 |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.nfs_mount](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_ssm_parameter.output_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| file_system_id | EFS file system Id | `string` | n/a | yes |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| mount_point | NFS mount point | `string` | `"/mnt/efs"` | no |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->