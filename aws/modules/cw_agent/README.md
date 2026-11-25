# cw_agent terraform module

Terraform module cw_agent configures CloudWatch agents on the deployment's EC2 instances.

The module also creates a CloudWatch log group used by the CloudWatch agents to send logs to.

The module uses [ssm_cloudwatch_config.py](../../scripts/ssm_cloudwatch_config.py) to run
`AmazonCloudWatch-ManageAgent` on the deployment's EC2 instances. On Windows, the
script resolves the deployment tags to an exact set of EC2 instance IDs, waits
for all of them to come online in SSM, and reports each invocation's result.
Command stdout and stderr from the Windows step are stored in S3 and replayed
into the Terraform apply log. The collector does not wait for files from the
document's Linux/macOS steps or for empty streams. This is separate from ongoing
CloudWatch agent monitoring. If the apply fails after submission, check the
command ID in SSM before reapplying.

## Requirements

The S3 bucket for the SSM command output is retrieved from "/arcgis/{var.enterprise_id}/s3/logs" SSM parameter.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.10 |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.cloudwatch_agent_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [null_resource.ssm_cloudwatch_config](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.output_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| platform | Platform (windows\|linux) | `string` | `"windows"` | no |
| linux_disk_resources | Linux filesystem mounts monitored for free space; base enterprise passes `/` and `/opt` | `list(string)` | `["/"]` | no |

## Outputs

| Name | Description |
|------|-------------|
| log_group_name | CloudWatch log group name |
