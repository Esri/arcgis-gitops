<!-- BEGIN_TF_DOCS -->
# Backup Terraform Module for ArcGIS Server on Linux

The Terraform module creates a backup of ArcGIS Server deployment and copies the backup to S3 bucket.

The module runs 'backup' admin utility on the primary EC2 instance of the deployment.

## Requirements

The ArcGIS Server must be configured on the deployment by application terraform module for ArcGIS Server on Linux.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Ansible 2.16 or later must be installed
* arcgis.common and arcgis.server Ansible collections must be installed
* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable

The module retrieves the backup S3 bucket name from '/arcgis/${var.site_id}/s3/backup' SSM parameters.

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.22 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| arcgis_server_backup | ../../modules/ansible_playbook | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.s3_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_password | ArcGIS Server administrator user password | `string` | n/a | yes |
| admin_username | ArcGIS Server administrator user name | `string` | `"siteadmin"` | no |
| deployment_id | Deployment Id | `string` | `"arcgis-server"` | no |
| run_as_user | User name for the account used to run ArcGIS Server | `string` | `"arcgis"` | no |
| s3_prefix | Backup S3 object keys prefix | `string` | `"arcgis-server-backups"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis-enterprise"` | no |
<!-- END_TF_DOCS -->