# Packer Template for ArcGIS Notebook Server on Linux AMI

The Packer template builds an EC2 AMI for a specific ArcGIS Notebook Server deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.enterprise_id}/images/${var.os}".

> Note: For RHEL9, the user data script installs and starts SSM Agent. Ubuntu 22.04 and 24.04 base images must already have SSM Agent installed and running; the template does not install it for these operating systems.

The template first uses [initialize_image_data_disk.sh](scripts/initialize_image_data_disk.sh) and the neighboring [initialize_data_disk.sh](scripts/initialize_data_disk.sh) to initialize the dedicated data EBS volume and mount it at `/opt`.

Next, it copies installation media for the ArcGIS Notebook Server version and required third-party dependencies from My Esri and public repositories to the private repository S3 bucket. The files to be copied are specified in the `../manifests/arcgis-notebook-server-s3files-${var.arcgis_version}.json` index file.

Then the template uses scripts to run SSM commands on the source EC2 instance to:

1. Install AWS CLI
2. Install Docker CE
3. If "gpu_ready" input variable is set to `true`, install NVIDIA driver, CUDA toolkit, and NVIDIA Container Toolkit
4. Install CloudWatch Agent
5. Install Cinc Client and Chef Cookbooks for ArcGIS
6. Download setups from the private repository S3 bucket
7. Install ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
8. Install patches for the ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
9. Delete unused files and uninstall Cinc Client
10. Verify the saved `/opt` filesystem UUID, Notebook installation, and effective Docker root before publishing the AMI

ID of the built AMI is saved in "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/node" SSM parameters.

## Requirements

On the machine where Packer is executed:

* The working directory must be set to `aws/arcgis-notebook-server-linux/image` relative to the repository root, because provisioners use relative `scripts/` paths
* Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
* Path to aws/scripts directory must be added to PYTHONPATH
* AWS CLI must be installed and configured
* AWS credentials must be configured
* Bash, GNU `base64` (`-w0`), and `jq` must be available on the runner
* My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD

## SSM Parameters

The template reads the following SSM parameters:

| SSM parameter name | Description |
| -------------------- | ------------- |
| /arcgis/${var.enterprise_id}/chef-client-url/${var.os} | Chef Client URL |
| /arcgis/${var.enterprise_id}/cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
| /arcgis/${var.enterprise_id}/iam/instance-profile-name | IAM instance profile name |
| /arcgis/${var.enterprise_id}/images/${var.os} | Source AMI ID |
| /arcgis/${var.enterprise_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.enterprise_id}/s3/region | S3 buckets region code |
| /arcgis/${var.enterprise_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.enterprise_id}/vpc/subnets | IDs of VPC subnets |

The template writes the following SSM parameters:

| SSM parameter name | Description |
| -------------------- | ------------- |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/node | Node AMI ID |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/notebook-server-web-context | Notebook Server web context name |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system identifier |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary | Primary AMI ID |

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| arcgis_notebook_server_patches | File names of ArcGIS Notebook Server patches to install | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Notebook Server version | `string` | `"12.1"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `list(string)` | `[]` | no |
| aws_region | AWS region ID | `string` | `env("AWS_DEFAULT_REGION")` | no |
| data_disk_size | Data EBS volume size in GiB (integer 32-16384) | `number` | `256` | no |
| deployment_id | Deployment ID | `string` | `"notebook-server-linux"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| gpu_ready | If true, the AMI is built with GPU support | `bool` | `false` | no |
| instance_type | EC2 instance type | `string` | `"m7i.2xlarge"` | no |
| license_level | ArcGIS Notebook Server license level | `string` | `"standard"` | no |
| notebook_server_web_context | ArcGIS Notebook Server web context | `string` | `"notebooks"` | no |
| os | Operating system ID (rhel9\|ubuntu22\|ubuntu24) | `string` | `"rhel9"` | no |
| os_disk_size | OS EBS volume size in GiB (integer 256-16384) | `number` | `256` | no |
| run_as_user | User account used to run ArcGIS Notebook Server | `string` | `"arcgis"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
