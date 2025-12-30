<!-- BEGIN_TF_DOCS -->
# Restore Terraform Module for ArcGIS Server on Linux

The Terraform module retrieves the last a backup from S3 bucket and restores ArcGIS Server deployment from the backup.

The module runs 'restore' admin utility on the primary EC2 instance of the deployment.

The backup is retrieved from the backup S3 bucket of the site specified by "backup_site_id" input variable.

## Requirements

The ArcGIS Server must be configured on the deployment by application terraform module for ArcGIS Server on Linux.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Ansible 2.16 or later must be installed
* arcgis.common and arcgis.server Ansible collections must be installed
* AWS credentials must be configured

The module retrieves the backup S3 bucket name and region from '/arcgis/${var.backup_site_id}/s3/backup' and
'/arcgis/${var.backup_site_id}/s3/region' SSM parameters.

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.10 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| arcgis_server_restore | ../../modules/ansible_playbook | n/a |
| backup_site_core_info | ../../modules/site_core_info | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_password | ArcGIS Server administrator user password | `string` | n/a | yes |
| admin_username | ArcGIS Server administrator user name | `string` | `"siteadmin"` | no |
| aws_region | AWS region Id | `string` | n/a | yes |
| backup_site_id | ArcGIS site Id of the backup to restore from | `string` | `"arcgis"` | no |
| deployment_id | Deployment Id | `string` | `"server-linux"` | no |
| run_as_user | User name for the account used to run ArcGIS Server | `string` | `"arcgis"` | no |
| s3_prefix | Backup S3 object keys prefix | `string` | `"arcgis-server-backups"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis"` | no |
<!-- END_TF_DOCS -->