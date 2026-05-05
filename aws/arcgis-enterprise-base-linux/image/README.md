# Packer Template for Base ArcGIS Enterprise on Linux AMI

The Packer templates builds EC2 AMI for a specific base ArcGIS Enterprise deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.enterprise_id}/images/${var.os}".

> Note: If the base image does not have SSM Agent installed, it's installed using user data script.

The template first copies installation media for the ArcGIS Enterprise version and required third party dependencies from My Esri and public repositories to the private repository S3 bucket. The files to be copied are  specified in ../manifests/arcgis-enterprise-s3files-${var.arcgis_version}.json index file.

Then the template uses python scripts to run SSM commands on the source EC2 instance to:

1. Install AWS CLI
2. Install CloudWatch Agent
3. Install Cinc Client and Chef Cookbooks for ArcGIS
4. Download setups from the private repository S3 bucket.
5. Install base ArcGIS Enterprise applications
6. Install patches for the base ArcGIS Enterprise applications
7. Delete unused files and uninstall Cinc Client

ID of the built AMI is saved in "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/standby" SSM parameters.

## Requirements

On the machine where Packer is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS CLI must be installed and configured
* AWS credentials must be configured
* My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD

## SSM Parameters

The template uses the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.enterprise_id}/chef-client-url/${var.os} | Chef Client URL |
| /arcgis/${var.enterprise_id}/cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
| /arcgis/${var.enterprise_id}/iam/instance-profile-name | IAM instance profile name|
| /arcgis/${var.enterprise_id}/images/${var.os} | Source AMI ID|
| /arcgis/${var.enterprise_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.enterprise_id}/s3/region | S3 buckets region code |
| /arcgis/${var.enterprise_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.enterprise_id}/vpc/subnets | Ids of VPC subnets |

The template writes the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary | Primary AMI ID for the deployment |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/standby | Standby AMI ID for the deployment |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system of the AMI |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/portal-web-context | Portal for ArcGIS web context |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context | ArcGIS Server web context |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_data_store_patches |File names of ArcGIS Data Store patches to install | `string` | `[]` | no |
| arcgis_portal_patches | File names of Portal for ArcGIS patches to install | `string` | `[]` | no |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Enterprise version | `string` | `"12.0"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `string` | `[]` | no |
| aws_region | AWS region ID | `string` | `env("AWS_DEFAULT_REGION")` | no |
| deployment_id | Deployment ID | `string` | `"enterprise-base-linux"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| instance_type | EC2 instance type | `string` | `"6i.xlarge"` | no |
| os | Operating system ID (rhel9\|ubuntu22\|ubuntu24) | `string` | `"rhel9"` | no |
| portal_web_context | Portal for ArcGIS web context | `string` | `"portal"` | no |
| root_volume_size | Root EBS volume size in GB | `number` | `100` | no |
| run_as_user | User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Server web context | `string` | `"server"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
