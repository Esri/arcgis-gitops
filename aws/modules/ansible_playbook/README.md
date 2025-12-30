<!-- BEGIN_TF_DOCS -->
# Terraform module ansible_playbook

Terraform module runs Ansible playbooks on the deployment's EC2 instances in specific roles.

The module uses community.aws.aws_ssm connection plugin to connect to EC2 instances via AWS Systems Manager.

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
| aws | ~> 6.10 |
| local | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.inventory](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_sensitive_file.external_vars](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [null_resource.ansible_playbook](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.ansible_aws_ssm_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| external_vars | Ansible external vars | `any` | n/a | yes |
| machine_roles | List of machine roles. | `list(string)` | n/a | yes |
| playbook | Ansible playbook | `string` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->