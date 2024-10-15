# Packer Template for Base ArcGIS Enterprise on Linux AMI

The Packer templates builds EC2 AMI for a specific base ArcGIS Enterprise deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".

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

Id of the built AMI is saved in "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}" SSM parameter.

## Requirements

On the machine where Packer is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured.

My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.

## SSM Parameters

The template uses the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
| /arcgis/${var.site_id}/cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
| /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name|
| /arcgis/${var.site_id}/images/${var.os} | Source AMI Id|
| /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.site_id}/s3/region | S3 buckets region code |
| /arcgis/${var.site_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.site_id}/vpc/private-subnet/1 | Private VPC subnet Id|

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_region | AWS region Id | `string` | `env("AWS_DEFAULT_REGION")` | no |
| arcgis_data_store_patches |File names of ArcGIS Data Store patches to install | `string` | `[]` | no |
| arcgis_portal_patches | File names of Portal for ArcGIS patches to install | `string` | `[]` | no |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Enterprise version | `string` | `"11.3"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `string` | `[]` | no |
| instance_type | EC2 instance type | `string` | `"6i.xlarge"` | no |
| java_version | OpenJDK version | `string` | `"11.0.20"` | no |
| os | Operating system | `string` | `"rhel8"` | no |
| root_volume_size | Root EBS volume size in GB | `number` | `100` | no |
| run_as_user | User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store | `string` | `"arcgis"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis-enterprise"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
| tomcat_version | Apache Tomcat version | `string` | `"9.0.48"` | no |
