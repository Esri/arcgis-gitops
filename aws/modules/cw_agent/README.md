<!-- BEGIN_TF_DOCS -->
# cw_agent terraform module

Terraform module cw_agent configures CloudWatch agents on the deployment's EC2 instances.

The module also creates a CloudWatch log group used by the CloudWatch agents to send logs to.

The module uses ssm_cloudwatch_config.py script to run AmazonCloudWatch-ManageAgent SSM command on the deployment's EC2 instances in specific roles.

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
| [aws_cloudwatch_log_group.deployment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ssm_parameter.cloudwatch_agent_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [null_resource.ssm_cloudwatch_config](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_ssm_parameter.output_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enteprise deployment Id | `string` | n/a | yes |
| platform | Platform (windows\|linux) | `string` | `"windows"` | no |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| log_group_name | CloudWatch log group name |
<!-- END_TF_DOCS -->