# Packer Template for Base ArcGIS Enterprise on Windows AMIs

The Packer template builds application and file-server EC2 AMIs for a specific base ArcGIS Enterprise deployment.

The AMIs are built from a Windows OS base image specified by SSM parameter "/arcgis/${var.enterprise_id}/images/${var.os}".

The application build first copies installation media for the ArcGIS Enterprise version and required third-party dependencies from My Esri and public repositories to the private repository S3 bucket. The files to copy are specified in the `../manifests/arcgis-enterprise-s3files-${var.arcgis_version}.json` index file.

Then the application build uses Python and Bash scripts to run SSM commands on its source EC2 instance:

1. Install AWS CLI
2. Install CloudWatch Agent
3. Install Cinc Client and Chef Cookbooks for ArcGIS
4. Initialize and verify the data disk as writable NTFS D:
5. Download setups from the private repository S3 bucket
6. Install base ArcGIS Enterprise applications
7. Install patches for the base ArcGIS Enterprise applications
8. Reverify the data disk and install the `ArcGISDataDisk` startup task, which validates the existing disk.
9. Delete unused files, uninstall Cinc Client, and run Sysprep

The application AMI ID is saved in both "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/standby" SSM parameters.

A separate Packer build creates the file-server AMI from the same base Windows OS AMI without installing the ArcGIS application stack. Through SSM, it installs AWS CLI using `ssm_install_awscli`, initializes and verifies its attached data disk as writable NTFS D:, installs AmazonCloudWatchAgent using `ssm_package`, and runs Sysprep using `ssm_clean_up` with Cinc Client uninstallation disabled. All commands target the `packer-fileserver` role; a failed step stops the build. Its AMI ID is published at "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/fileserver" only after the file-server build succeeds. Both builds explicitly configure the OS disk using `os_disk_size` and the encrypted gp3 profile described below; deployment-time OS-disk settings are applied separately by the infrastructure module.

## Requirements

On the machine where Packer is executed:

* Packer and its Amazon plugin must be installed; run `packer init .` in this image directory to initialize the plugin
* Bash, `jq`, `iconv`, and GNU-compatible `base64` supporting `-w0` must be available
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
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/fileserver | Built file-server AMI ID |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary | Primary AMI ID for the deployment |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/standby | Standby AMI ID for the deployment |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system of the AMI |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/portal-web-context | Portal for ArcGIS web context |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context | ArcGIS Server web context |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_data_store_patches | File names of ArcGIS Data Store patches to install | `list(string)` | `[]` | no |
| arcgis_portal_patches | File names of Portal for ArcGIS patches to install | `list(string)` | `[]` | no |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Enterprise version | `string` | `"12.1"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `list(string)` | `[]` | no |
| aws_region | AWS region ID | `string` | `env("AWS_DEFAULT_REGION")` | no |
| deployment_id | Deployment ID | `string` | `"enterprise-base-windows"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| fileserver_data_disk_size | Persistent file-server data disk capacity baked into its AMI in GiB | `number` | `256` | no |
| instance_type | EC2 instance type | `string` | `"m7i.2xlarge"` | no |
| os | Operating system ID | `string` | `"windows2025"` | no |
| portal_web_context | Portal for ArcGIS web context | `string` | `"portal"` | no |
| os_disk_size | OS EBS disk size in GiB for application and file-server images | `number` | `256` | no |
| data_disk_size | Persistent application data disk capacity baked into the image in GiB | `number` | `256` | no |
| run_as_password | Password for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `env("RUN_AS_PASSWORD")` | yes |
| run_as_user | User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Server web context | `string` | `"server"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
