<!-- BEGIN_TF_DOCS -->
# Terraform module arcgis_dsc

Terraform module runs runs ArcGIS.Invoke-ArcGISConfiguration cmdlet with specified
configuration parameters on the deployment's EC2 instances in specified roles.

The module uses arcgis.windows.invoke_arcgis_configuration Ansible playbook with
community.aws.aws_ssm connection plugin to connect to EC2 instances via AWS Systems Manager.

## Requirements

The name of the S3 bucket used by the SSM connection for file transfers is retrieved from "/arcgis/{var.site_id}/s3/logs" SSM parameter.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Ansible must be installed
* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable

## Providers

| Name | Version |
|------|---------|
| local | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| invoke_arcgis_configuration | ../ansible_playbook | n/a |

## Resources

| Name | Type |
|------|------|
| [local_sensitive_file.configuration_parameters_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| execution_timeout | Timeout in seconds | `number` | `3600` | no |
| install_mode | Installation mode | `string` | `"InstallLicenseConfigure"` | no |
| json_attributes | Configuration parameters in JSON format | `string` | n/a | yes |
| machine_roles | List of machine roles. | `list(string)` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->