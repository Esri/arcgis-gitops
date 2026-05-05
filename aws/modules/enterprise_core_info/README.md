<!-- BEGIN_TF_DOCS -->
# Terraform module enterprise_core_info

Terraform module enterprise_core_info retrieves names and IDs of core AWS resources
created by infrastructure-core module from AWS Systems Manager parameters and
returns them as output values.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.hosted_zone_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.instance_profile_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.s3_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.s3_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.s3_region](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.s3_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.vpc_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| hosted_zone_id | Private hosted zone ID |
| instance_profile_name | Name of IAM instance profile |
| internal_subnets | Internal subnets |
| private_subnets | Private subnets |
| public_subnets | Public subnets |
| s3_backup | Backups S3 bucket name |
| s3_logs | Logs S3 bucket name |
| s3_region | S3 region |
| s3_repository | Private repository S3 bucket name |
| vpc_id | VPC ID of ArcGIS Enterprise |
<!-- END_TF_DOCS -->