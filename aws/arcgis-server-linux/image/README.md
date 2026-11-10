# Packer Template for ArcGIS Server on Linux AMI

The Packer template builds an EC2 AMI for a specific ArcGIS Server deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.enterprise_id}/images/${var.os}".

> Note: For RHEL 9, user data installs, enables, and starts SSM Agent. Ubuntu 22.04 and 24.04 base images must already provide a running SSM Agent. Provisioning uses SSM, not SSH.

The template first copies installation media for the ArcGIS Server version and required third-party dependencies from My Esri and public repositories to the private repository S3 bucket. The files to be copied are specified in the `../manifests/arcgis-server-s3files-${var.arcgis_version}.json` index file.

Then the template uses Python and Bash scripts to run SSM commands on the source EC2 instance to:

 1. Install AWS CLI on the instance.
 2. Initialize the dedicated data EBS volume and mount it at `/opt`, preserving baseline content.
 3. Install CloudWatch Agent, EFS utilities, Chef Client, and cookbooks.
 4. Download setups from the private repository S3 bucket.
 5. Install OpenJDK and Apache Tomcat.
 6. Install ArcGIS Server and ArcGIS Web Adaptor with name specified by `server_web_context`.
 7. Install ArcGIS Server and ArcGIS Web Adaptor patches.
 8. Verify that `/opt/arcgis/server` resides on the data filesystem.
 9. Delete unused files.

On a successful AMI build, the same AMI ID is saved in "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/node" SSM parameters.

## Requirements

On the machine where Packer is executed:

* Packer must be installed. Run `packer init .` in this directory to install the required Amazon plugin (`>= 1.1.1`).
* Python 3.8 or later with an [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) release compatible with the selected interpreter must be installed.
* Path to `aws/scripts` directory must be added to `PYTHONPATH`.
* AWS CLI must be installed and configured.
* Bash, `jq`, and GNU-compatible `base64` supporting `-w0` must be installed. Run Packer from this image directory in a full repository checkout.
* Set `AWS_DEFAULT_REGION` or supply the `aws_region` input explicitly.
* AWS credentials must be configured.
* My Esri user name and password must be specified using environment variables `ARCGIS_ONLINE_USERNAME` and `ARCGIS_ONLINE_PASSWORD`.
* The source instance must be reachable through SSM in the selected private subnet,
with access to the required SSM services, installation repositories, and S3 buckets.

## SSM Parameters

The template uses the following SSM parameters:

| SSM parameter name | Description |
| -------------------- | ------------- |
| /arcgis/${var.enterprise_id}/chef-client-url/${var.os} | URL of the Chef client installer |
| /arcgis/${var.enterprise_id}/cookbooks-url | URL of the Chef cookbooks archive |
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
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context | ArcGIS Server web context name |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system identifier |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary | Primary AMI ID |

## Inputs

| Name | Description | Type | Default | Required |
| ------ | ------------- | ------ | --------- | :--------: |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Server version | `string` | `"12.1"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `list(string)` | `[]` | no |
| aws_region | AWS region ID | `string` | `env("AWS_DEFAULT_REGION")` | no |
| data_disk_size | Data EBS capacity baked into the image in GiB; integer 32-16384 | `number` | `256` | no |
| deployment_id | Deployment ID | `string` | `"server-linux"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| instance_type | EC2 instance type | `string` | `"m7i.2xlarge"` | no |
| os | Operating system ID: rhel9, ubuntu22, or ubuntu24 | `string` | `"rhel9"` | no |
| os_disk_size | OS EBS disk size in GiB; integer 256-16384 | `number` | `256` | no |
| run_as_user | User account used to run ArcGIS Server | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Web Adaptor name | `string` | `"arcgis"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
