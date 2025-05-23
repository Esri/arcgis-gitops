/**
 * # Packer Template for ArcGIS Notebook Server AMI
 * 
 * The Packer templates builds EC2 AMI for a specific ArcGIS Notebook Server deployment.
 * 
 * The AMI is built from the operating system's base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".
 * 
 * The template first copies installation media for the ArcGIS Notebook Server version
 * and required third party dependencies from My Esri and public repositories 
 * to the private repository S3 bucket. The files to be copied are specified in 
 * ../manifests/arcgis-notebook-server-s3files-${var.arcgis_version}.json index file.
 * 
 * Then the template uses python scripts to run SSM commands on the source EC2 instance to:
 * 
 * 1. Install AWS CLI
 * 2. Install CloudWatch Agent
 * 3. Install Cinc Client and Chef Cookbooks for ArcGIS
 * 4. Download setups from the private repository S3 bucket.
 * 5. Install ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
 * 6. Install patches for the ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
 * 7. Delete unused files and uninstall Cinc Client
 * 
 * Id of the built AMI is saved in "/arcgis/${var.site_id}/images/${var.deployment_id}/primary" and 
 * "/arcgis/${var.site_id}/images/${var.deployment_id}/node" SSM parameters.
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
 * The template writes the following SSM parameters:
 * 
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
 * | /arcgis/${var.site_id}/cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name|
 * | /arcgis/${var.site_id}/images/${var.os} | Source AMI Id|
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/s3/region | S3 buckets region code |
 * | /arcgis/${var.site_id}/s3/repository | Private repository S3 bucket |
 * | /arcgis/${var.site_id}/vpc/subnets | IDs of VPC subnets |
 *
 * The template writes the following SSM parameters:
 *
 * | SSM parameter name | Description |
 * |--------------------|-------------|
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/primary | Primary AMI Id |
 * | /arcgis/${var.site_id}/images/${var.deployment_id}/node | Node AMI Id |
 */

# Copyright 2025 Esri
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
  region = var.aws_region
}

data "amazon-parameterstore" "subnets" {
  name = "/arcgis/${var.site_id}/vpc/subnets"
  region = var.aws_region  
}

data "amazon-parameterstore" "instance_profile_name" {
  name = "/arcgis/${var.site_id}/iam/instance-profile-name"
  region = var.aws_region  
}

data "amazon-parameterstore" "s3_repository" {
  name  = "/arcgis/${var.site_id}/s3/repository"
  region = var.aws_region  
}

data "amazon-parameterstore" "s3_logs" {
  name  = "/arcgis/${var.site_id}/s3/logs"
  region = var.aws_region  
}

data "amazon-parameterstore" "s3_region" {
  name  = "/arcgis/${var.site_id}/s3/region"
  region = var.aws_region  
}

data "amazon-parameterstore" "chef_client_url" {
  name  = "/arcgis/${var.site_id}/chef-client-url/${var.os}"
  region = var.aws_region  
}

data "amazon-parameterstore" "chef_cookbooks_url" {
  name  = "/arcgis/${var.site_id}/cookbooks-url"
  region = var.aws_region  
}

locals {
  manifest_file_path =  "${path.root}/../manifests/arcgis-notebook-server-s3files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  java_tarball       = local.manifest.arcgis.repository.metadata.java_tarball
  java_version       = local.manifest.arcgis.repository.metadata.java_version
  tomcat_tarball     = local.manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version     = local.manifest.arcgis.repository.metadata.tomcat_version

  machine_role = "packer"
  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  ami_name  = "${var.site_id}-${var.deployment_id}-${var.arcgis_version}-${var.os}-${local.timestamp}"
  ami_description = "ArcGIS Notebook Server ${var.arcgis_version} AMI for ${var.os}"
  software_dir = "/opt/software/setups/*"

  # Platform-specific attributes

  chef_client_url = "{{ssm:/arcgis/${var.site_id}/chef-client-url/${var.os}}}"

  # Configure GPG key for docker repository
  ubuntu_user_data = <<-EOF
  #!/bin/bash
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  EOF

  user_data = var.install_docker ? (contains(["ubuntu20", "ubuntu22"], var.os) ? local.ubuntu_user_data : null) : null
}

source "amazon-ebs" "main" {
  region        = var.aws_region  
  ami_name      = local.ami_name
  ami_description = local.ami_description
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.source_ami.value
  subnet_id     = jsondecode(data.amazon-parameterstore.subnets.value).private[0]
  iam_instance_profile = data.amazon-parameterstore.instance_profile_name.value
  communicator  = "none"
  user_data     = local.user_data
  
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
    ArcGISSiteId       = var.site_id    
    ArcGISVersion      = var.arcgis_version
    ArcGISDeploymentId = var.deployment_id    
    ArcGISMachineRole  = local.machine_role
    OperatingSystem    = var.os
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
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m s3_copy_files -f ${local.manifest_file_path} -b ${data.amazon-parameterstore.s3_repository.value}"
  }

  # Install AWS CLI
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_install_awscli -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Install CloudWatch Agent
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }
  
  # Install Amazon EFS Utils
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -p AmazonEFSUtils -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Bootstrap
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -c ${data.amazon-parameterstore.chef_client_url.value} -k ${data.amazon-parameterstore.chef_cookbooks_url.value} -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Download setups
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
      JSON_ATTRIBUTES = base64encode(templatefile(
        local.manifest_file_path, 
        { 
          s3bucket = data.amazon-parameterstore.s3_repository.value, 
          region = data.amazon-parameterstore.s3_region.value
        }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-notebook-server/image/${var.arcgis_version}/${var.os}/s3files -b ${data.amazon-parameterstore.s3_logs.value} -e 1200"
  }

  # Install
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
      JSON_ATTRIBUTES = base64encode(jsonencode({
        java = {
          version = local.java_version
          tarball_path = "${local.archives_dir}/${local.java_tarball}"
        }
        tomcat = {
          version = local.tomcat_version
          tarball_path = "${local.archives_dir}/${local.tomcat_tarball}"
          install_path = "/opt/tomcat_arcgis_${local.tomcat_version}"
        }
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          configure_autofs = false
          packages = [ "jq", "docker-ce" ]
          repository = {
            archives = local.archives_dir
            setups = "/opt/software/setups"
          }
          web_server = {
            webapp_dir = "/opt/tomcat_arcgis_${local.tomcat_version}/webapps"
          }
          notebook_server = {
            install_dir = "/opt"
            install_system_requirements = true
            # install_docker = var.install_docker
            license_level = var.license_level
            configure_autostart = true
            wa_name = var.notebook_server_web_context
          }
          web_adaptor = {
            install_dir = "/opt"
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::system]",
          # "recipe[arcgis-notebooks::docker]",
          "recipe[esri-tomcat::openjdk]",
          "recipe[esri-tomcat::install]",
          "recipe[arcgis-notebooks::iptables]",
          "recipe[arcgis-notebooks::restart_docker]",
          "recipe[arcgis-notebooks::install_server]",
          "recipe[arcgis-notebooks::install_server_wa]"                    
        ]
      }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-notebook-server/image/${var.arcgis_version}/${var.os}/install -b ${data.amazon-parameterstore.s3_logs.value} -e 3600"
  }

  # Install patches
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          repository = {
            patches = local.patches_dir
          }
          notebook_server = {
            install_dir = "/opt"
            patches = var.arcgis_notebook_server_patches
          }
          web_adaptor = {
            install_dir = "/opt"
            patches = var.arcgis_web_adaptor_patches
          }
        }
        run_list = [
          "recipe[arcgis-notebooks::install_patches]",
          "recipe[arcgis-enterprise::install_patches]"
        ]
      }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-notebook-server/image/${var.arcgis_version}/${var.os}/patches -b ${data.amazon-parameterstore.s3_logs.value} -e 3600"
  }

  # Clean up
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m ssm_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -f ${local.software_dir} -b ${data.amazon-parameterstore.s3_logs.value}"
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

  # Retrieve the the AMI Id from packer-manifest.json manifest file and save it in SSM parameters.
  post-processor "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m publish_artifact -p /arcgis/${var.site_id}/images/${var.deployment_id}/primary -f packer-manifest.json -r ${build.PackerRunUUID}"
  }

  post-processor "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m publish_artifact -p /arcgis/${var.site_id}/images/${var.deployment_id}/node -f packer-manifest.json -r ${build.PackerRunUUID}"
  }
}
