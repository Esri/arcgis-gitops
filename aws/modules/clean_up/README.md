<!-- BEGIN_TF_DOCS -->
# Terraform module clean_up

Terraform module deletes files in specific directories on EC2 instances in specific roles.
Optionally, if the uninstall_chef_client variable is set to true, the module also uninstalls Chef client on the instances.

The module uses ssm_clean_up.py script to run {var.site-id}-clean-up SSM command on the deployment's EC2 instances in specific roles.

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
| [null_resource.clean_up](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_ssm_parameter.output_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| directories | List of directories to clean up | `list(string)` | `[]` | no |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
| uninstall_chef_client | Set to true to uninstall Chef/Cinc Client | `bool` | `true` | no |
<!-- END_TF_DOCS -->