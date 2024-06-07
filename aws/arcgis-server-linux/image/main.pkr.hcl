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
 * 1. Install AWS CLI
 * 2. Install CloudWatch Agent
 * 3. Download setups from the private repository S3 bucket.
 * 4. Install ArcGIS Server
 * 5. Install ArcGIS Server patches
 * 6. Delete unused files
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
  sudo yum -y install python3.11 python3.11-pip
  sudo rm /usr/bin/python3
  sudo ln -s /usr/bin/python3.11 /usr/bin/python3
  sudo rm /usr/bin/pip3
  sudo ln -s /usr/bin/pip3.11 /usr/bin/pip3
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

  s3_files_json_path =  "${abspath(path.root)}/../manifests/arcgis-server-s3files-${var.arcgis_version}.json"
  
  external_vars = yamlencode({
    ansible_aws_ssm_bucket_name = data.amazon-parameterstore.s3_logs.value
    ansible_aws_ssm_region = data.amazon-parameterstore.s3_region.value
    ansible_connection = "aws_ssm"
    arcgis_server_patches = var.arcgis_server_patches
    arcgis_version = var.arcgis_version
    bucket_name = data.amazon-parameterstore.s3_repository.value
    local_repository = "/opt/software/archives"
    manifest = local.s3_files_json_path
    region = data.amazon-parameterstore.s3_region.value
    run_as_user = var.run_as_user
    ansible_python_interpreter="/usr/bin/python3"
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

  # Copy files to private S3 repository
  provisioner "shell-local" {
    command = "python -m s3_copy_files -f ${local.s3_files_json_path} -u ${var.arcgis_online_username} -p ${var.arcgis_online_password} -b ${data.amazon-parameterstore.s3_repository.value}"
  }

  # Install CloudWatch Agent
  provisioner "shell-local" {
    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Download setups from private S3 repository and install ArcGIS Server   
  provisioner "shell-local" {
    inline = [
      "echo '${local.external_vars}' > /tmp/external_vars.yaml",
      "echo '${local.inventory}' > /tmp/inventory.aws_ec2.yaml",
      "ansible-playbook arcgis.server.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/external_vars.yaml",
      "ansible-playbook arcgis.server.install -i /tmp/inventory.aws_ec2.yaml -e @/tmp/external_vars.yaml",
      "ansible-playbook arcgis.server.patch -i /tmp/inventory.aws_ec2.yaml -e @/tmp/external_vars.yaml"
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
