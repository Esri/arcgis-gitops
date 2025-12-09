<!-- BEGIN_TF_DOCS -->
# Application Terraform Module for ArcGIS Notebook Server on Linux

The Terraform module configures or upgrades applications of highly available ArcGIS Notebook Server deployment on Linux platform.

![ArcGIS Notebook Server on Linux](arcgis-notebook-server-linux-application.png "ArcGIS Notebook Server on Linux")

First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all EC2 instances of the deployment.

If "is_upgrade" input variable is set to `true`, the module:

* Copies the installation media for the ArcGIS Enterprise version specified by arcgis_version input variable to the private repository S3 bucket
* Downloads the installation media from the private repository S3 bucket to primary and node EC2 instances
* Installs/upgrades  ArcGIS Enterprise software on primary and node EC2 instances
* Installs the software patches on primary and node EC2 instances

Then the module:

* Copies the ArcGIS Notebook Server authorization file to the private repository S3 bucket
* If specified, copies keystore and root certificate files to the private repository S3 bucket
* Downloads the ArcGIS Notebook Server authorization file from the private repository S3 bucket to primary and node EC2 instances
* If specified, downloads the keystore and root certificate files from the private repository S3 bucket to primary and node EC2 instances
* Creates the required directories in the NFS mount
* Configures ArcGIS Notebook Server on primary EC2 instance
* Configures ArcGIS Notebook Server on node EC2 instance
* Deletes the downloaded setup archives, the extracted setups, and other temporary files from primary and node EC2 instances
* Subscribes the primary ArcGIS Notebook Server administrator e-mail address to the SNS topic of the monitoring subsystem

## Requirements

The AWS resources for the deployment must be provisioned by Infrastructure terraform module for ArcGIS Notebook Server on Linux.

On the machine where Terraform is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* The working directory must be set to the arcgis-notebook-server-linux/application module path
* AWS credentials must be configured

My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.

## SSM Parameters

The module reads the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/${var.deployment_id}/backup/plan-id | Backup plan ID for the deployment |
| /arcgis/${var.site_id}/${var.deployment_id}/content-s3-bucket | S3 bucket for the portal content |
| /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the deployment |
| /arcgis/${var.site_id}/${var.deployment_id}/notebook-server-web-context | ArcGIS Notebook Server web context |
| /arcgis/${var.site_id}/${var.deployment_id}/portal-url | Portal for ArcGIS URL (if portal_url is not specified) |
| /arcgis/${var.site_id}/${var.deployment_id}/sns-topic-arn | SNS topic ARN of the monitoring subsystem |
| /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
| /arcgis/${var.site_id}/cookbooks-url | Chef cookbooks URL |
| /arcgis/${var.site_id}/iam/backup-role-arn | ARN of IAM role used by AWS Backup service |
| /arcgis/${var.site_id}/s3/backup | S3 bucket for the backup |
| /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM command output |
| /arcgis/${var.site_id}/s3/repository | S3 bucket for the private repository |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| arcgis_notebook_server_federation | ../../modules/run_chef | n/a |
| arcgis_notebook_server_files | ../../modules/run_chef | n/a |
| arcgis_notebook_server_fileserver | ../../modules/run_chef | n/a |
| arcgis_notebook_server_node | ../../modules/run_chef | n/a |
| arcgis_notebook_server_patch | ../../modules/run_chef | n/a |
| arcgis_notebook_server_primary | ../../modules/run_chef | n/a |
| arcgis_notebook_server_upgrade | ../../modules/run_chef | n/a |
| authorization_files | ../../modules/run_chef | n/a |
| backup | ../../modules/backup | n/a |
| bootstrap_deployment | ../../modules/bootstrap | n/a |
| clean_up | ../../modules/clean_up | n/a |
| keystore_file | ../../modules/run_chef | n/a |
| root_cert | ../../modules/run_chef | n/a |
| s3_copy_files | ../../modules/s3_copy_files | n/a |
| site_core_info | ../../modules/site_core_info | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_s3_object.keystore_file](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.notebook_server_authorization_file](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.root_cert_file](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_sns_topic_subscription.infrastructure_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_instance.primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instance) | data source |
| [aws_instances.nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/instances) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.deployment_fqdn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.notebook_server_web_context](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.portal_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.sns_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_email | ArcGIS Notebook Server administrator e-mail address | `string` | n/a | yes |
| admin_password | Primary ArcGIS Notebook Server administrator user password | `string` | n/a | yes |
| admin_username | Primary ArcGIS Notebook Server administrator user name | `string` | `"siteadmin"` | no |
| arcgis_notebook_server_patches | File names of ArcGIS Server patches to install. | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Notebook Server version | `string` | `"12.0"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install. | `list(string)` | `[]` | no |
| aws_region | AWS region Id | `string` | n/a | yes |
| config_store_type | ArcGIS Server configuration store type | `string` | `"FILESYSTEM"` | no |
| deployment_id | Deployment Id | `string` | `"notebook-server-linux"` | no |
| is_upgrade | Flag to indicate if this is an upgrade deployment | `bool` | `false` | no |
| keystore_file_password | Password for keystore file with SSL certificate used by HTTPS listeners | `string` | `""` | no |
| keystore_file_path | Local path of keystore file in PKCS12 format with SSL certificate used by HTTPS listeners | `string` | `null` | no |
| license_level | ArcGIS Notebook Server license level | `string` | `"standard"` | no |
| log_level | ArcGIS Notebook Server log level | `string` | `"WARNING"` | no |
| notebook_server_authorization_file_path | Local path of ArcGIS Notebook Server authorization file | `string` | n/a | yes |
| notebook_server_authorization_options | Additional ArcGIS Notebook Server software authorization command line options | `string` | `""` | no |
| os | Operating system id (rhel9\|ubuntu22) | `string` | `"rhel9"` | no |
| portal_org_id | ArcGIS Enterprise organization Id | `string` | `null` | no |
| portal_password | Portal for ArcGIS user password | `string` | `null` | no |
| portal_url | Portal for ArcGIS URL | `string` | `null` | no |
| portal_username | Portal for ArcGIS user name | `string` | `null` | no |
| root_cert_file_path | Local path of root certificate file in PEM format used by ArcGIS Server and Portal for ArcGIS | `string` | `null` | no |
| run_as_user | User name for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `"arcgis"` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |

## Outputs

| Name | Description |
|------|-------------|
| arcgis_notebook_server_private_url | ArcGIS Notebook Server URL |
| arcgis_notebook_server_url | ArcGIS Notebook Server URL |
<!-- END_TF_DOCS -->