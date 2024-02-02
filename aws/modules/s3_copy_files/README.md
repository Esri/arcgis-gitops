<!-- BEGIN_TF_DOCS -->
# Terraform module s3_copy_files

Terraform module s3_copy_files copies files from local file system, public URLs, and, My Esri repository to S3 bucket.

The module uses s3_copy_files.py script to copy files defined in a JSON index file to an S3 bucket.

## Requirements

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable
* My Esri user name and password must be specified either by environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or using the input variables.

## Providers

| Name | Version |
|------|---------|
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.s3_copy_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_online_password | ArcGIS Online user password | `string` | `null` | no |
| arcgis_online_username | ArcGIS Online user name | `string` | `null` | no |
| bucket_name | S3 bucket name | `string` | n/a | yes |
| index_file | Index file local path | `string` | n/a | yes |
<!-- END_TF_DOCS -->