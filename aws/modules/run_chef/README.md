<!-- BEGIN_TF_DOCS -->
# Terraform module run_chef

Terraform module run_chef runs Cinc client in zero mode on EC2 instances in specified roles.

The module runs ssm_run_chef.py python script that creates a SecureString SSM parameter with Chef JSON attributes and
runs {var.site-id}-run-chef SSM command on the deployment's EC2 instances in specific roles.

## Requirements

The S3 bucket for the SSM command output is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable

 Cinc client and Chef Cookbooks for ArcGIS must be installed on the target EC2 instances.

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.10 |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.run_chef](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.output_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| execution_timeout | Chef run timeout in seconds | `number` | `3600` | no |
| json_attributes | Chef run attributes in JSON format | `string` | n/a | yes |
| machine_roles | List of machine roles. | `list(string)` | n/a | yes |
| parameter_name | Name of the SSM parameter to store the value of json_attributes variable | `string` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->