/**
 * # Packer Template for ArcGIS Server on Windows
 * 
 * The Packer templates builds EC2 AMIs for a specific ArcGIS Server deployment.
 * 
 * The AMIs are built from the operating system's base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".
 * 
 * On main instance the template runs python scripts and Ansible playbooks on the source EC2 instance to:
 *
 * 1. Install CloudWatch Agent
 * 2. Copy ArcGIS Server and (optionally) ArcGIS Web Adapor setups to the private S3 repository
 * 3. Install ArcGIS PowerShell module
 * 4. Download setups from private S3 repository to the EC2 instance
 * 5. Run Invoke-ArcGISConfiguration cmdlet to install ArcGIS Server, patches, and (optionally) ArcGIS Web Adaptor
 * 6. Delete unused files, run sysprep
 * 
 * On fileserver instance:
 * 
 * 1. Install CloudWatch Agent
 * 2. Delete unused files, run sysprep
 * 
 * Ids of the main and fileserver AMIs are saved in "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}" 
 * and "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver" SSM parameters.
 * 
 * ## Requirements
 * 
 * On the machine where Packer is executed:
 * 
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * AWS credentials must be configured.
 * * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
 * * Path to the ZIP archive with ArcGIS PowerShell DSC module must be specified using environment variable ARCGIS_POWERSHELL_ZIP_PATH.
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
  timestamp = formatdate("YYYYMMDDhhmm", timestamp())

  machine_role = "packer"
  ami_name  = "arcgis-server-${var.arcgis_version}-${var.os}-${local.timestamp}"
  ami_description = "ArcGIS Server ${var.arcgis_version} AMI for ${var.os}"

  fileserver_machine_role = "packer-fileserver"
  fileserver_ami_name  = "arcgis-server-fileserver-${var.os}-${local.timestamp}"
  fileserver_ami_description = "ArcGIS Server fileserver AMI for ${var.os}"

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

  fileserver_inventory = yamlencode({
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
      "tag:ArcGISMachineRole" = local.fileserver_machine_role
    }
  })

  arcgis_server_s3_files =  "${abspath(path.root)}/../manifests/arcgis-server-s3files-${var.arcgis_version}.json"
  arcgis_webadaptor_s3_files =  "${abspath(path.root)}/../manifests/arcgis-webadaptor-s3files-${var.arcgis_version}.json"
  
  local_repository = "C:\\Software\\Archives"

  arcgis_server_setup_archives = {
    "11.2" = "ArcGIS_Server_Windows_112_188239.exe"
    "11.3" = "ArcGIS_Server_Windows_113_190188.exe"
  }

  arcgis_webadaptor_setup_archives = {
    "11.2" = "ArcGIS_Web_Adaptor_for_Microsoft_IIS_112_188253.exe"
    "11.3" = "ArcGIS_Web_Adaptor_for_Microsoft_IIS_113_190234.exe"
  }

  configuration_json_file_path = "/tmp/arcgis_server_install.json"

  arcgis_server_install_json = jsonencode({
    AllNodes = [
      {
        NodeName = "localhost"
        Role = var.install_webadaptor ? [
          "Server",
          "WebAdaptor"
        ] : [
          "Server"
        ]
        WebAdaptorConfig = {
          Role = "Server"
          Context = var.webadaptor_name
        }
      }
    ]
    ConfigData = {
      Version = var.arcgis_version
      ServerRole = "GeneralPurposeServer"
      Credentials = {
        ServiceAccount = {
          Password = var.run_as_password
          UserName = var.run_as_user
          IsDomainAccount = false
          IsMSAAccount = false
        }
      }
      Server = {
        Installer = {
          Path = "${local.local_repository}\\${local.arcgis_server_setup_archives[var.arcgis_version]}"
          IsSelfExtracting = true
          InstallDir = "C:\\Program Files\\ArcGIS\\Server"
          PatchesDir = "${local.local_repository}\\Patches"
          PatchInstallOrder = var.arcgis_server_patches
        }
      }
      WebAdaptor = {
        AdminAccessEnabled = true
        Installer = {
          Path = "${local.local_repository}\\${local.arcgis_webadaptor_setup_archives[var.arcgis_version]}"
          DotnetHostingBundlePath = "${local.local_repository}\\dotnet-hosting-win.exe"
          WebDeployPath = "${local.local_repository}\\WebDeploy_amd64_en-US.msi"
          IsSelfExtracting = true
        }
      }
    }
  })

  ansible_properties = {
    ansible_aws_ssm_bucket_name = data.amazon-parameterstore.s3_logs.value
    ansible_aws_ssm_region = data.amazon-parameterstore.s3_region.value
    ansible_connection = "aws_ssm"
    ansible_shell_type = "powershell"
  }

  fileserver_vars = yamlencode(local.ansible_properties)

  server_vars = yamlencode(merge(
    local.ansible_properties, 
    {
      region = data.amazon-parameterstore.s3_region.value
      arcgis_version = var.arcgis_version
      bucket_name = data.amazon-parameterstore.s3_repository.value
      local_repository = replace(local.local_repository, "\\", "\\\\")
      manifest = local.arcgis_server_s3_files
      configuration_parameters_file = local.configuration_json_file_path
      install_mode = "Install"
    }
  ))

  webadaptor_vars = yamlencode(merge(
    local.ansible_properties, 
    {  
      region = data.amazon-parameterstore.s3_region.value
      arcgis_version = var.arcgis_version
      bucket_name = data.amazon-parameterstore.s3_repository.value
      local_repository = replace(local.local_repository, "\\", "\\\\")
      manifest = local.arcgis_webadaptor_s3_files
    }
  ))
}

source "amazon-ebs" "main" {
  ami_name      = local.ami_name
  ami_description = local.ami_description
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.source_ami.value
  subnet_id     = data.amazon-parameterstore.subnet.value
  iam_instance_profile = data.amazon-parameterstore.instance_profile_name.value
  communicator = "none"
  
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

source "amazon-ebs" "fileserver" {
  ami_name      = local.fileserver_ami_name
  ami_description = local.fileserver_ami_description
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.source_ami.value
  subnet_id     = data.amazon-parameterstore.subnet.value
  iam_instance_profile = data.amazon-parameterstore.instance_profile_name.value
  communicator = "none"
  
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
    Name = local.fileserver_ami_name
    ArcGISSiteId = var.site_id    
    ArcGISDeploymentId = var.deployment_id    
    ArcGISMachineRole = local.fileserver_machine_role
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

  # Create configuration JSON file for ArcGIS Server and ArcGIS Web Adaptor installation
  provisioner "shell-local" {
    env = {
      ARCGIS_SERVER_INSTALL_JSON = base64encode(local.arcgis_server_install_json)
    }
    inline = [
      "echo $ARCGIS_SERVER_INSTALL_JSON | base64 --decode > ${local.configuration_json_file_path}"
    ]
  }

  # Copy ArcGIS Server and (optionally) ArcGIS Web Adapor setups to the private S3 repository.
  # Install ArcGIS PowerShell module on the EC2 instances.
  # Download setups from private S3 repository to the EC2 instances.
  # Install ArcGIS Server, patches, and (optionally) ArcGIS Web Adaptor.
  # Delete the setup files.
  provisioner "shell-local" {
    inline = [
      "echo '${local.server_vars}' > /tmp/server_vars.yaml",
      "echo '${local.webadaptor_vars}' > /tmp/webadaptor_vars.yaml",
      "echo '${local.inventory}' > /tmp/inventory.aws_ec2.yaml",
      "python -m s3_copy_files -f ${local.arcgis_server_s3_files} -b ${data.amazon-parameterstore.s3_repository.value}",      
      var.install_webadaptor ? "python -m s3_copy_files -f ${local.arcgis_webadaptor_s3_files} -b ${data.amazon-parameterstore.s3_repository.value}" : "",
      "ansible-playbook arcgis.windows.bootstrap -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.windows.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      var.install_webadaptor ? "ansible-playbook arcgis.windows.s3_files -i /tmp/inventory.aws_ec2.yaml -e @/tmp/webadaptor_vars.yaml" : "",
      "ansible-playbook arcgis.windows.invoke_arcgis_configuration -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.windows.firewall_rule -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      # "ansible-playbook arcgis.windows.clean -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml",
      "ansible-playbook arcgis.windows.sysprep -i /tmp/inventory.aws_ec2.yaml -e @/tmp/server_vars.yaml"
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

build {
  name = "${var.deployment_id}-fileserver"
 
  sources = [
    "source.amazon-ebs.fileserver"
  ]

  # Install CloudWatch Agent
  provisioner "shell-local" {
    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.fileserver_machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # sysprep
  provisioner "shell-local" {
    inline = [
      "echo '${local.fileserver_vars}' > /tmp/fileserver_vars.yaml",
      "echo '${local.fileserver_inventory}' > /tmp/fileserver_inventory.aws_ec2.yaml",
      "ansible-playbook arcgis.windows.sysprep -i /tmp/fileserver_inventory.aws_ec2.yaml -e @/tmp/fileserver_vars.yaml"
    ]
  }

  # Save the build artifacts metadata in packer-manifest.json file.
  # Note: New builds add new artifacts to packer-manifest.json file.
  post-processor "manifest" {
    output = "fileserver-packer-manifest.json"
    strip_path = true
    custom_data = {
      ami_description = local.fileserver_ami_description
    }
  }

  # Retrive the the AMI Id from fileserver-packer-manifest.json manifest file and save it in SSM parameter.
  post-processor "shell-local" {
    command = "python -m publish_artifact -p /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver -f fileserver-packer-manifest.json -r ${build.PackerRunUUID}"
  }
}
