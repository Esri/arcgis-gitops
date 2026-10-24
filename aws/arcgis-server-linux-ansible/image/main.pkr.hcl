# Copyright 2024-2026 Esri
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
  name   = "/arcgis/${var.enterprise_id}/images/${var.os}"
  region = var.aws_region
}

data "amazon-parameterstore" "subnets" {
  name   = "/arcgis/${var.enterprise_id}/vpc/subnets"
  region = var.aws_region
}

data "amazon-parameterstore" "instance_profile_name" {
  name   = "/arcgis/${var.enterprise_id}/iam/instance-profile-name"
  region = var.aws_region
}

data "amazon-parameterstore" "s3_repository" {
  name   = "/arcgis/${var.enterprise_id}/s3/repository"
  region = var.aws_region
}

data "amazon-parameterstore" "s3_logs" {
  name   = "/arcgis/${var.enterprise_id}/s3/logs"
  region = var.aws_region
}

data "amazon-parameterstore" "s3_region" {
  name   = "/arcgis/${var.enterprise_id}/s3/region"
  region = var.aws_region
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
      var.aws_region
    ]
    compose = {
      ansible_host = "instance_id"
    }
    filters = {
      "instance-state-name" = "running"
      "tag:ArcGISEnterpriseID" = var.enterprise_id
      "tag:ArcGISDeploymentID" = var.deployment_id
      "tag:ArcGISMachineRole" = local.machine_role
    }
  })

  arcgis_server_manifest_path =  "${abspath(path.root)}/../manifests/arcgis-server-s3files-${var.arcgis_version}.json"
  server_manifest    = jsondecode(file(local.arcgis_server_manifest_path))
  archives_dir       = local.server_manifest.arcgis.repository.local_archives
  patches_dir        = local.server_manifest.arcgis.repository.local_patches

  arcgis_webadaptor_manifest_path =  "${abspath(path.root)}/../manifests/arcgis-webadaptor-s3files-${var.arcgis_version}.json"
  webadaptor_manifest = jsondecode(file(local.arcgis_webadaptor_manifest_path))
  java_tarball        = local.webadaptor_manifest.arcgis.repository.metadata.java_tarball
  java_version        = local.webadaptor_manifest.arcgis.repository.metadata.java_version
  tomcat_tarball      = local.webadaptor_manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version      = local.webadaptor_manifest.arcgis.repository.metadata.tomcat_version  

  server_vars = yamlencode({
    ansible_aws_ssm_bucket_name = data.amazon-parameterstore.s3_logs.value
    ansible_aws_ssm_region = data.amazon-parameterstore.s3_region.value
    ansible_connection = "aws_ssm"
    arcgis_server_patches = var.arcgis_server_patches
    arcgis_version = var.arcgis_version
    bucket_name = data.amazon-parameterstore.s3_repository.value
    local_repository =  local.archives_dir
    patches_directory = local.patches_dir
    manifest = local.arcgis_server_manifest_path
    region = var.aws_region
    run_as_user = var.run_as_user
    # ansible_python_interpreter="/usr/bin/python3"
  })

  webadaptor_vars = yamlencode({
    ansible_aws_ssm_bucket_name = data.amazon-parameterstore.s3_logs.value
    ansible_aws_ssm_region = data.amazon-parameterstore.s3_region.value
    ansible_connection = "aws_ssm"
    arcgis_version = var.arcgis_version
    wa_name = var.server_web_context
    bucket_name = data.amazon-parameterstore.s3_repository.value
    local_repository =  local.archives_dir
    manifest = local.arcgis_webadaptor_manifest_path
    region = var.aws_region
    jdk_version = local.java_version
    jdk_setup_archive = local.java_tarball
    tomcat_version = local.tomcat_version
    tomcat_setup_archive = local.tomcat_tarball
    # ansible_python_interpreter="/usr/bin/python3"
  })
}

source "amazon-ebs" "main" {
  region        = var.aws_region
  ami_name      = local.ami_name
  ami_description = local.ami_description
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.source_ami.value
  subnet_id     = jsondecode(data.amazon-parameterstore.subnets.value).private[0]
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
    Name               = local.ami_name
    ArcGISAutomation   = "arcgis-gitops"
    ArcGISEnterpriseID = var.enterprise_id    
    ArcGISVersion      = var.arcgis_version
    ArcGISDeploymentID = var.deployment_id    
    ArcGISMachineRole  = local.machine_role
    OperatingSystem    = var.os    
  }

  skip_create_ami = var.skip_create_ami
}

build {
  name   = var.deployment_id
 
  sources = [
    "source.amazon-ebs.main"
  ]

  # Install CloudWatch Agent
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_package -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Install Amazon EFS Utils
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_package -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonEFSUtils -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Download setups from private S3 repository and install ArcGIS Server   
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    inline = [
      "echo '${local.server_vars}' > /tmp/server_vars.yaml",
      "echo '${local.inventory}' > /tmp/inventory.aws_ec2.yaml",
      "python -m s3_copy_files -f ${local.arcgis_server_manifest_path} -b ${data.amazon-parameterstore.s3_repository.value}",      
      "ansible-playbook arcgis.common.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.common.system -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.server.firewalld -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",      
      "ansible-playbook arcgis.server.install -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.server.patch -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.common.clean -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml"
    ]
  }

  # Download setups from private S3 repository and install ArcGIS Web Adaptor
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    inline = var.use_webadaptor ? [
      "echo '${local.webadaptor_vars}' > /tmp/webadaptor_vars.yaml",
      "echo '${local.inventory}' > /tmp/inventory.aws_ec2.yaml",
      "python -m s3_copy_files -f ${local.arcgis_webadaptor_manifest_path} -b ${data.amazon-parameterstore.s3_repository.value}",
      "ansible-playbook arcgis.common.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml",
      "ansible-playbook arcgis.webadaptor.openjdk -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml",
      "ansible-playbook arcgis.webadaptor.tomcat -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml",
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

  # Retrieve the the AMI ID from packer-manifest.json manifest file and save it in SSM parameters.
  post-processor "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m publish_artifact -p /arcgis/${var.enterprise_id}/images/${var.deployment_id}/primary -f packer-manifest.json -r ${build.PackerRunUUID}"
  }

  post-processor "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m publish_artifact -p /arcgis/${var.enterprise_id}/images/${var.deployment_id}/node -f packer-manifest.json -r ${build.PackerRunUUID}"
  }

  # Save os and server_web_context in SSM parameters for later use in deployment.
  post-processor "shell-local" {
    command = "aws ssm put-parameter --name /arcgis/${var.enterprise_id}/images/${var.deployment_id}/os --value ${var.os} --overwrite --type String --region ${var.aws_region}"
  }

  post-processor "shell-local" {
    command = "aws ssm put-parameter --name /arcgis/${var.enterprise_id}/images/${var.deployment_id}/server-web-context --value ${var.server_web_context} --overwrite --type String --region ${var.aws_region}"
  }
}
