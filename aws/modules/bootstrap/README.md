<!-- BEGIN_TF_DOCS -->
# Terraform module bootstrap

Terraform module installs or upgrades Chef client and Chef Cookbooks for ArcGIS on EC2 instances.

The module uses ssm_bootstrap.py script to run {var.enterprise_id}-bootstrap SSM command on the deployment's EC2 instances in specific roles.

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
| [null_resource.bootstrap](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.chef_client_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.chef_cookbooks_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| chef_client_url | S3 or HTTP URL of Chef client installer | `string` | `null` | no |
| chef_cookbooks_url | S3 or HTTP URL of ArcGIS Chef cookbooks archive | `string` | `null` | no |
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| os | Operating system ID | `string` | n/a | yes |
| output_s3_bucket | S3 bucket for the SSM command output | `string` | n/a | yes |
<!-- END_TF_DOCS -->