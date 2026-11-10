# Packer Template for ArcGIS Server on Linux AMI

The Packer template builds an EC2 AMI for a specific ArcGIS Server Enterprise deployment.

The AMI is built from a Linux OS base image specified by SSM parameter "/arcgis/${var.enterprise_id}/images/${var.os}".

> Note: If the base image does not have SSM Agent installed, it's installed using user data script.

The supported OS is RHEL 9. The AMI has an OS gp3 volume at `/dev/sda1`
and a dedicated encrypted gp3 data volume at `/dev/sdf`, mounted at `/opt`.
Both default to 256 GiB and use 16000 IOPS / 1000 MiB/s during the image build.
Only the data mapping explicitly requests encryption; OS encryption follows the
source image and account EBS settings.

After disk initialization, Python SSM helpers install CloudWatch Agent and Amazon EFS Utils on the source EC2 instance. The template does not install AWS CLI on that instance.

Next, the template uses Python to copy ArcGIS Server installation media and patches from My Esri and public repositories to the private repository S3 bucket. The files are specified in the `../manifests/arcgis-server-s3files-${var.arcgis_version}.json` index file. Ansible playbooks connect to the instance through SSM to:

1. Download setups and patches from the private repository S3 bucket
2. Configure system requirements and firewall rules
3. Install ArcGIS Server
4. Install patches for ArcGIS Server
5. Clean up downloaded setup files

If `use_webadaptor` is `true`, the template copies the additional media listed in `../manifests/arcgis-webadaptor-s3files-${var.arcgis_version}.json` to the private repository S3 bucket, then uses Ansible playbooks to:

1. Download the additional setups from the private repository S3 bucket
2. Install OpenJDK
3. Install Apache Tomcat
4. Configure firewall rules and install ArcGIS Web Adaptor with the name specified by `server_web_context`
5. Clean up downloaded setup files

After installation, `verify-server` checks that `/opt/arcgis/server` resides on
the saved data filesystem. The installed `arcgis-data-disk.service` verifies
the UUID mount and grows ext4 when a larger volume is restored. Systemd drop-ins
make `arcgisserver` and optional `tomcat_arcgis` wait for that guard and `/opt`;
the guard does not require or start an absent Tomcat service. EFS remains at
`/mnt/efs` and is not part of this disk.

The wrapper modes are `initialize`, `verify`, `initialize-server`, and
`verify-server`; this template uses the two Server modes. Both select the
`arcgisserver tomcat_arcgis` service list. The guest script receives this list
and verification flags as environment variables, not positional arguments.

ID of the built AMI is saved in "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary" and "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/node" SSM parameters.

## Requirements

On the machine where Packer is executed:

* The working directory must be set to `aws/arcgis-server-linux-ansible/image` relative to the repository root, because provisioners use relative `scripts/` paths
* Packer with the Amazon plugin initialized using `packer init` for this image directory
* Bash, GNU `base64` (including `-w0`), and `jq`
* Python compatible with the installed `ansible-core` version, with the [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package installed
* Path to aws/scripts directory must be added to PYTHONPATH
* Ansible with `ansible-core` 2.16 or later must be installed; the supplied workflow installs the Ansible 9.x distribution (`ansible>=9.0,<10.0`), which includes `ansible-core` 2.16
* arcgis.common, arcgis.server, and arcgis.webadaptor Ansible collections must be installed
* AWS CLI must be installed and configured
* AWS credentials must be configured
* My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD

## SSM Parameters

The template uses the following SSM parameters:

| SSM parameter name | Description |
| --- | --- |
| /arcgis/${var.enterprise_id}/iam/instance-profile-name | IAM instance profile name |
| /arcgis/${var.enterprise_id}/images/${var.os} | Source AMI ID |
| /arcgis/${var.enterprise_id}/s3/logs | S3 bucket for SSM commands output |
| /arcgis/${var.enterprise_id}/s3/region | S3 buckets region code |
| /arcgis/${var.enterprise_id}/s3/repository | Private repository S3 bucket |
| /arcgis/${var.enterprise_id}/vpc/subnets | IDs of VPC subnets |

The template writes the following SSM parameters:

| SSM parameter name | Description |
| --- | --- |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/node | Node AMI ID |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context | ArcGIS Server web context name |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os | Operating system identifier |
| /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary | Primary AMI ID |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | :---: |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Server version | `string` | `"12.1"` | no |
| aws_region | AWS region ID | `string` | `env("AWS_DEFAULT_REGION")` | no |
| data_disk_size | Image-backed `/opt` capacity in GiB; integer 32-16384 | `number` | `256` | no |
| deployment_id | Deployment ID | `string` | `"server-linux-ansible"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| instance_type | EC2 instance type | `string` | `"m7i.2xlarge"` | no |
| os | Operating system ID | `string` | `"rhel9"` | no |
| os_disk_size | OS disk capacity in GiB; integer 256-16384 | `number` | `256` | no |
| run_as_user | User account used to run ArcGIS Server | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Web Adaptor name | `string` | `"arcgis"` | no |
| skip_create_ami | If true, Packer will not create the AMI | `bool` | `false` | no |
| use_webadaptor | If true, OpenJDK, Apache Tomcat, and ArcGIS Web Adaptor will be installed on the AMI. | `bool` | `false` | no |
