 # Packer Template for ArcGIS Server on Windows

The Packer templates builds EC2 AMIs for a specific ArcGIS Server deployment.

The AMIs are built from the operating system's base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".

On main instance the template runs python scripts and Ansible playbooks on the source EC2 instance to:

1. Install CloudWatch Agent
2. Copy ArcGIS Server and (optionally) ArcGIS Web Adapor setups to the private S3 repository
3. Install ArcGIS PowerShell module
4. Download setups from private S3 repository to the EC2 instance
5. Run Invoke-ArcGISConfiguration cmdlet to install ArcGIS Server, patches, and (optionally) ArcGIS Web Adaptor
6. Delete unused files, run sysprep

On fileserver instance:

1. Install CloudWatch Agent
2. Delete unused files, run sysprep

Ids of the main and fileserver AMIs are saved in "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}"
and "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver" SSM parameters.

## Requirements

On the machine where Packer is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS credentials must be configured.
* My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
* Path to the ZIP archive with ArcGIS PowerShell DSC module must be specified using environment variable ARCGIS_POWERSHELL_ZIP_PATH.
  
## SSM Parameters

The template uses the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name|
| /arcgis/${var.site_id}/images/${var.os} | Source AMI Id|
| /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.site_id}/s3/region | S3 buckets region code |
| /arcgis/${var.site_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.site_id}/vpc/private-subnet-1 | Private VPC subnet Id|

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_server_patches | File names of ArcGIS Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Server version | `string` | `"11.3"` | no |
| deployment_id | Deployment Id | `string` | `"arcgis-server"` | no |
| instance_type | EC2 instance type | `string` | `"6i.xlarge"` | no |
| os | Operating system | `string` | `"windows2022"` | no |
| root_volume_size | Root EBS volume size in GB | `number` | `100` | no |
| run_as_user | User account used to run ArcGIS Server | `string` | `"arcgis"` | no |
| run_as_password | Password for the account used to run ArcGIS Server | `string` | | yes |
| site_id | ArcGIS site Id | `string` | `"arcgis-enterprise"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
| install_webadaptor | If true, ArcGIS Web Adaptor (IIS) will be installed on the AMI | `bool` | `false` | no |
| webadaptor_name | ArcGIS Web Adaptor name | `string` | `"arcgis"` | no |
