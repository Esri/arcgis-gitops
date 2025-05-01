# Packer Template for ArcGIS Notebook Server on Linux AMI

The Packer templates builds EC2 AMI for a specific ArcGIS Notebook Server deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".

> Note: If the base image does not have SSM Agent installed, it's installed using user data script.

The template first copies installation media for the ArcGIS Notebook Server version and required third party dependencies from My Esri and public repositories to the private repository S3 bucket. The files to be copied are  specified in ../manifests/arcgis-notebook-server-s3files-${var.arcgis_version}.json index file.

Then the template uses python scripts to run SSM commands on the source EC2 instance to:

1. Install AWS CLI
2. Install CloudWatch Agent
3. Install Cinc Client and Chef Cookbooks for ArcGIS
4. Download setups from the private repository S3 bucket.
5. Install ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
6. Install patches for the ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
7. Delete unused files and uninstall Cinc Client

Id of the built AMI is saved in "/arcgis/${var.site_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.site_id}/images/${var.deployment_id}/node" SSM parameters.

## Requirements

On the machine where Packer is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured.

My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.

## SSM Parameters

The template reads the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
| /arcgis/${var.site_id}/cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
| /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name|
| /arcgis/${var.site_id}/images/${var.os} | Source AMI Id|
| /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.site_id}/s3/region | S3 buckets region code |
| /arcgis/${var.site_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.site_id}/vpc/subnets | Ids of VPC subnets |

The template writes the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/images/${var.deployment_id}/primary | Primary AMI Id |
| /arcgis/${var.site_id}/images/${var.deployment_id}/node | Node AMI Id |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_region | AWS region Id | `string` | `env("AWS_DEFAULT_REGION")` | no |
| arcgis_notebook_server_patches | File names of ArcGIS Notebook Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Notebook Server version | `string` | `"11.4"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `string` | `[]` | no |
| deployment_id | Deployment Id | `string` | `"notebook-server-linux"` | no |
| install_docker | If true, Docker will be installed | `bool` | `true` | no |
| instance_type | EC2 instance type | `string` | `"6i.xlarge"` | no |
| license_level | ArcGIS Notebook Server license level | `string` | `"standard"` | no |
| os | Operating system | `string` | `"ubuntu22"` | no |
| root_volume_size | Root EBS volume size in GB | `number` | `100` | no |
| run_as_user | User account used to run ArcGIS Notebook Server | `string` | `"arcgis"` | no |
| notebook_server_web_context | ArcGIS Notebook Server web context | `string` | `"notebooks"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
