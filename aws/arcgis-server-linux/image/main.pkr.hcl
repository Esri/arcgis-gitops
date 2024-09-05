/**
 * # Packer Template for ArcGIS Server AMI
 * 
 * The Packer templates builds EC2 AMI for a specific ArcGIS Server deployment.
 * 
 * The AMI is built from the operating system's base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".
 * 
 * > Note: If the base image does not have SSM Agent installed, it's installed using user data script.
 * 
 * The template first copies installation media for the ArcGIS Server version
 * and required third party dependencies from My Esri and public repositories 
 * to the private repository S3 bucket. The files to be copied are specified in 
 * ../manifests/arcgis-server-s3files-${var.arcgis_version}.json index file.
 * 
 * Then the template uses python scripts to run SSM commands on the source EC2 instance to:
 * 
 * 1. Install CloudWatch Agent
 * 2. Download setups from the private repository S3 bucket.
 * 3. Install ArcGIS Server
 * 4. Install ArcGIS Server patches
 * 5. Delete unused files
 *
 * If the "install_webadaptor" variable is set to true, the template will also:
 *
 * 1. Install OpenJDK
 * 2. Install Apache Tomcat
 * 3. Install ArcGIS Web Adaptor with name specified by "webadaptor_name" variable.
 * 
 * Id of the built AMI is saved in "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}" SSM parameter.
 * 
 * ## Requirements
 * 
 * On the machine where Packer is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured.
 * * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
 * 
 * ## SSM Parameters
 * 
 * The template uses the following SSM parameters:
 * 
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name|
 * | /arcgis/${var.site_id}/images/${var.os} | Source AMI Id|
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/s3/region | S3 buckets region code |
 * | /arcgis/${var.site_id}/s3/repository | Private repository S3 bucket |
 * | /arcgis/${var.site_id}/vpc/private-subnet-1 | Private VPC subnet Id|
 */

# Copyright 2024 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
 
packer {
  required_plugins {
    amazon = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

data "amazon-parameterstore" "source_ami" {
  name = "/arcgis/${var.site_id}/images/${var.os}"
}

data "amazon-parameterstore" "subnet" {
  name = "/arcgis/${var.site_id}/vpc/private-subnet-1"
}

data "amazon-parameterstore" "instance_profile_name" {
  name = "/arcgis/${var.site_id}/iam/instance-profile-name"
}

data "amazon-parameterstore" "s3_repository" {
  name  = "/arcgis/${var.site_id}/s3/repository"
}

data "amazon-parameterstore" "s3_logs" {
  name  = "/arcgis/${var.site_id}/s3/logs"
}

data "amazon-parameterstore" "s3_region" {
  name  = "/arcgis/${var.site_id}/s3/region"
}

locals {
  machine_role = "packer"
  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  ami_name  = "arcgis-server-${var.arcgis_version}-${var.os}-${local.timestamp}"
  ami_description = "ArcGIS Server ${var.arcgis_version} AMI for ${var.os}"
  software_dir = "/opt/software/*"

  # Platform-specific attributes

  # Install SSM Agent on RHEL EC2 instances in user-data script.
  rhel_user_data = <<-EOF
  #!/bin/bash
  cd /tmp
  sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  sudo systemctl enable amazon-ssm-agent
  sudo systemctl start amazon-ssm-agent
  EOF

  user_data = contains(["rhel8", "rhel9"], var.os) ? local.rhel_user_data : null

  inventory = yamlencode({
    plugin = "amazon.aws.aws_ec2"
    regions = [ 
      data.amazon-parameterstore.s3_region.value 
    ]
    compose = {
      ansible_host = "instance_id"
    }
    filters = {
      "instance-state-name" = "running"
      "tag:ArcGISSiteId" = var.site_id
      "tag:ArcGISDeploymentId" = var.deployment_id
      "tag:ArcGISMachineRole" = local.machine_role
    }
  })

  arcgis_server_s3_files =  "${abspath(path.root)}/../manifests/arcgis-server-s3files-${var.arcgis_version}.json"
  arcgis_webadaptor_s3_files =  "${abspath(path.root)}/../manifests/arcgis-webadaptor-s3files-${var.arcgis_version}.json"
  
  server_vars = yamlencode({
    ansible_aws_ssm_bucket_name = data.amazon-parameterstore.s3_logs.value
    ansible_aws_ssm_region = data.amazon-parameterstore.s3_region.value
    ansible_connection = "aws_ssm"
    arcgis_server_patches = var.arcgis_server_patches
    arcgis_version = var.arcgis_version
    bucket_name = data.amazon-parameterstore.s3_repository.value
    # local_repository = "/opt/software/archives"
    manifest = local.arcgis_server_s3_files
    region = data.amazon-parameterstore.s3_region.value
    run_as_user = var.run_as_user
    # ansible_python_interpreter="/usr/bin/python3"
  })

  webadaptor_vars = yamlencode({
    ansible_aws_ssm_bucket_name = data.amazon-parameterstore.s3_logs.value
    ansible_aws_ssm_region = data.amazon-parameterstore.s3_region.value
    ansible_connection = "aws_ssm"
    arcgis_version = var.arcgis_version
    wa_name = var.webadaptor_name
    bucket_name = data.amazon-parameterstore.s3_repository.value
    # local_repository = "/opt/software/archives"
    manifest = local.arcgis_webadaptor_s3_files
    region = data.amazon-parameterstore.s3_region.value
    # ansible_python_interpreter="/usr/bin/python3"
  })
}

source "amazon-ebs" "main" {
  ami_name      = local.ami_name
  ami_description = local.ami_description
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.source_ami.value
  subnet_id     = data.amazon-parameterstore.subnet.value
  iam_instance_profile = data.amazon-parameterstore.instance_profile_name.value
  communicator = "none"
  user_data = local.user_data
  
  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_type = "gp3"
    volume_size = var.root_volume_size
    // encrypted   = true
    iops        = 16000
    throughput  = 1000
    delete_on_termination = true
  }

  run_tags = {
    Name = local.ami_name
    ArcGISSiteId = var.site_id    
    ArcGISVersion = var.arcgis_version
    ArcGISDeploymentId = var.deployment_id    
    ArcGISMachineRole = local.machine_role
  }

  skip_create_ami = var.skip_create_ami
}

build {
  name = var.deployment_id
 
  sources = [
    "source.amazon-ebs.main"
  ]

  # Install CloudWatch Agent
  provisioner "shell-local" {
    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Install Amazon EFS Utils
  provisioner "shell-local" {
    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonEFSUtils -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Download setups from private S3 repository and install ArcGIS Server   
  provisioner "shell-local" {
    inline = [
      "echo '${local.server_vars}' > /tmp/server_vars.yaml",
      "echo '${local.inventory}' > /tmp/inventory.aws_ec2.yaml",
      "python -m s3_copy_files -f ${local.arcgis_server_s3_files} -b ${data.amazon-parameterstore.s3_repository.value}",      
      "ansible-playbook arcgis.common.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.common.system -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.server.firewalld -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",      
      "ansible-playbook arcgis.server.install -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.server.patch -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.common.clean -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml"
    ]
  }

  # Download setups from private S3 repository and install ArcGIS Web Aaptor
  provisioner "shell-local" {
    inline = var.install_webadaptor ? [
      "echo '${local.webadaptor_vars}' > /tmp/webadaptor_vars.yaml",
      "echo '${local.inventory}' > /tmp/inventory.aws_ec2.yaml",
      "JDK_VERSION=$(cat ${local.arcgis_webadaptor_s3_files} | jq -r '.arcgis.repository.files.\"jdk_x64_linux.tar.gz\".version')",
      "TOMCAT_VERSION=$(cat ${local.arcgis_webadaptor_s3_files} | jq -r '.arcgis.repository.files.\"tomcat.tar.gz\".version')",
      "python -m s3_copy_files -f ${local.arcgis_webadaptor_s3_files} -b ${data.amazon-parameterstore.s3_repository.value}",
      "ansible-playbook arcgis.common.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml",
      "ansible-playbook arcgis.webadaptor.openjdk -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml -e jdk_version=$JDK_VERSION",
      "ansible-playbook arcgis.webadaptor.tomcat -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml -e tomcat_version=$TOMCAT_VERSION",
      "ansible-playbook arcgis.webadaptor.firewalld -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml",
      "ansible-playbook arcgis.webadaptor.install -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml",
      "ansible-playbook arcgis.common.clean -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml"
    ] : [
      "echo 'ArcGIS Web Adaptor installation is not enabled.'"
    ]
  }

  # Save the build artifacts metadata in packer-manifest.json file.
  # Note: New builds add new artifacts to packer-manifest.json file.
  post-processor "manifest" {
    output = "packer-manifest.json"
    strip_path = true
    custom_data = {
      ami_description = local.ami_description
    }
  }

  # Retrive the the AMI Id from packer-manifest.json manifest file and save it in SSM parameter.
  post-processor "shell-local" {
    command = "python -m publish_artifact -p /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id} -f packer-manifest.json -r ${build.PackerRunUUID}"
  }
}
