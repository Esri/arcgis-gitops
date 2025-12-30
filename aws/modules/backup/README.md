<!-- BEGIN_TF_DOCS -->
# Terraform module backup

Terraform module configures system-level backups in AWS Backup service of
the cloud configuration stores of different server roles.

## SSM Parameters

The module reads the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/${var.deployment_id}/backup/plan-id | Backup plan ID for the deployment |
| /arcgis/${var.site_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |

## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_backup_selection.application](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_dynamodb_tag.config_store_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_tag) | resource |
| [null_resource.tag_s3_bucket](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_dynamodb_table.config_store_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/dynamodb_table) | data source |
| [aws_dynamodb_table_item.config_store](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/dynamodb_table_item) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_resourcegroupstaggingapi_resources.dynamodb_tables_by_tag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/resourcegroupstaggingapi_resources) | data source |
| [aws_s3_bucket.config_store_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/s3_bucket) | data source |
| [aws_ssm_parameter.backup_plan_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.backup_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_application | ArcGIS Enterprise application type (server\|notebook-store) | `string` | `"server"` | no |
| arcgis_version | ArcGIS Enterprise version | `string` | n/a | yes |
| backup_s3_bucket | Backup the config store S3 bucket | `bool` | `false` | no |
| deployment_id | Deployment Id | `string` | `"enterprise-base-linux"` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |
<!-- END_TF_DOCS -->