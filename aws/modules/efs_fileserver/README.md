<!-- BEGIN_TF_DOCS -->
# Terraform module efs_fileserver

Terraform module creates or references an EFS file system for the deployment's file server.

If `fileserver_deployment_id` variable is null, the module creates a new EFS file system, security group, and EFS mount targets, and writes their IDs to SSM parameters.

If `fileserver_deployment_id` variable is not null, the module reads the EFS file system and security group IDs from SSM parameters for the specified deployment.

The security group of the EFS file system allows inbound NFS traffic from the security group specified by `referenced_security_group_id` variable.

## Requirements

On the machine where Terraform is executed:

* AWS credentials must be configured
* AWS region must be specified by AWS_DEFAULT_REGION environment variable

## SSM Parameters

The module reads the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/file-system-id | EFS file system ID (if ${var.fileserver_deployment_id} is not null) |
| /arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/security-group-id | EFS file system security group ID (if ${var.fileserver_deployment_id} is not null) |

The module writes the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/file-system-id | EFS file system ID (if ${var.fileserver_deployment_id} is null) |
| /arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/security-group-id | EFS file system security group ID (if ${var.fileserver_deployment_id} is null) |

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_efs_file_system.fileserver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.fileserver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_security_group.file_system_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.file_system_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.file_system_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.allow_nfs_from_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ssm_parameter.file_system_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.security_group_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| fileserver_deployment_id | Use the EFS filesystem from the deployment with the given ID. If not specified, a dedicated EFS filesystem will be created for this deployment. | `string` | `null` | no |
| referenced_security_group_id | List of security group IDs to reference in the EFS file system security group ingress rules. | `string` | n/a | yes |
| subnet_ids | EFS target subnet IDs. | `list(string)` | n/a | yes |
| vpc_id | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| file_system_arn | EFS file system ARN |
| file_system_id | EFS file system ID for the deployment's file server |
| security_group_id | Security group ID for the deployment's file server EFS file system |
<!-- END_TF_DOCS -->