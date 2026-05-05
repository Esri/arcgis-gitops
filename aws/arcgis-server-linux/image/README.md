# Packer Template for ArcGIS Server on Linux AMI

The Packer template builds EC2 AMI for a specific ArcGIS Server Enterprise deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.enterprise_id}/images/${var.os}".

> Note: If the base image does not have SSM Agent installed, it's installed using user data script.

The template first copies installation media for the ArcGIS Server version and required third party dependencies from My Esri and public repositories to the private repository S3 bucket. The files to be copied are  specified in ../manifests/arcgis-server-s3files-${var.arcgis_version}.json index file.

Then the template uses Python scripts to run SSM commands on the source EC2 instance to:

1. Install AWS CLI
2. Install CloudWatch Agent
3. Download setups from the private repository S3 bucket.
4. Install ArcGIS Server
5. Install patches for ArcGIS Server

If the "use_webadaptor" variable is set to true, the template will also:

1. Install OpenJDK
2. Install Apache Tomcat
3. Install ArcGIS Web Adaptor with name specified by "server_web_context" variable.

ID of the built AMI is saved in "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/node" SSM parameters.

## Requirements

On the machine where Packer is executed:

* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* Ansible 2.16 or later must be installed
* arcgis.common, arcgis.server, and arcgis.webadaptor Ansible collections must be installed
* AWS CLI must be installed and configured
* AWS credentials must be configured
* My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD

## SSM Parameters

The template uses the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.enterprise_id}/iam/instance-profile-name | IAM instance profile name |
| /arcgis/${var.enterprise_id}/images/${var.os} | Source AMI ID|
| /arcgis/${var.enterprise_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.enterprise_id}/s3/region | S3 buckets region code |
| /arcgis/${var.enterprise_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.enterprise_id}/vpc/subnets | IDs of VPC subnets |

The template writes the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/node | Node AMI ID |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context | ArcGIS Server web context name |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system identifier |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary | Primary AMI ID |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_server_patches | File names of ArcGIS Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Server version | `string` | `"12.0"` | no |
| aws_region | AWS region ID | `string` | `env("AWS_DEFAULT_REGION")` | no |
| deployment_id | Deployment ID | `string` | `"server-linux"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| instance_type | EC2 instance type | `string` | `"m6i.2xlarge"` | no |
| os | Operating system ID | `string` | `"rhel9"` | no |
| root_volume_size | Root EBS volume size in GB | `number` | `100` | no |
| run_as_user | User account used to run ArcGIS Server | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Web Adaptor name | `string` | `"arcgis"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
| use_webadaptor | If true, OpenJDK, Apache Tomcat, and ArcGIS Web Adaptor will be installed on the AMI. | `bool` | `false` | no |
