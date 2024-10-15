/**
 * # Packer Template for Base ArcGIS Enterprise AMI
 * 
 * The Packer templates builds EC2 AMI for a specific base ArcGIS Enterprise deployment.
 * 
 * The AMI is built from the operating system's base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".
 * 
 * > Note: If the base image does not have SSM Agent installed, it's installed using user data script.
 * 
 * The template first copies installation media for the ArcGIS Enterprise version
 * and required third party dependencies from My Esri and public repositories 
 * to the private repository S3 bucket. The files to be copied are specified in 
 * ../manifests/arcgis-enterprise-s3files-${var.arcgis_version}.json index file.
 * 
 * Then the template uses python scripts to run SSM commands on the source EC2 instance to:
 * 
 * 1. Install AWS CLI
 * 2. Install CloudWatch Agent
 * 3. Install Cinc Client and Chef Cookbooks for ArcGIS
 * 4. Download setups from the private repository S3 bucket.
 * 5. Install base ArcGIS Enterprise applications
 * 6. Install patches for the base ArcGIS Enterprise applications
 * 7. Delete unused files and uninstall Cinc Client
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
 * | /arcgis/${var.site_id}/chef-client-url/${var.os} | Chef Client URL |
 * | /arcgis/${var.site_id}/cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
 * | /arcgis/${var.site_id}/iam/instance-profile-name | IAM instance profile name|
 * | /arcgis/${var.site_id}/images/${var.os} | Source AMI Id|
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket for SSM commands output |
 * | /arcgis/${var.site_id}/s3/region | S3 buckets region code |
 * | /arcgis/${var.site_id}/s3/repository | Private repository S3 bucket |
 * | /arcgis/${var.site_id}/vpc/private-subnet/1 | Private VPC subnet Id|
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
  region = var.aws_region
}

data "amazon-parameterstore" "subnet" {
  name = "/arcgis/${var.site_id}/vpc/private-subnet/1"
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
  s3_files_json_path =  "${path.root}/../manifests/arcgis-enterprise-s3files-${var.arcgis_version}.json"

  machine_role = "packer"
  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  ami_name  = "arcgis-enterprise-base-${var.arcgis_version}-${var.os}-${local.timestamp}"
  ami_description = "Base ArcGIS Enterprise ${var.arcgis_version} AMI for ${var.os}"
  software_dir = "/opt/software/*"

  # Platform-specific attributes

  chef_client_url = "{{ssm:/arcgis/${var.site_id}/chef-client-url/${var.os}}}"

  # Install SSM Agent on RHEL EC2 instances in user-data script.
  rhel_user_data = <<-EOF
  #!/bin/bash
  cd /tmp
  sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  sudo systemctl enable amazon-ssm-agent
  sudo systemctl start amazon-ssm-agent
  EOF

  # Enable and start SSM Agent on SLES EC2 instances in user-data script.
  sles_user_data = <<-EOF
  #!/bin/bash
  sudo systemctl enable amazon-ssm-agent
  sudo systemctl start amazon-ssm-agent
  sudo zypper refresh --services
  EOF
  
  user_data = contains(["rhel8", "rhel9"], var.os) ? local.rhel_user_data : (contains(["sles15"], var.os) ? local.sles_user_data : null)
}

source "amazon-ebs" "main" {
  region        = var.aws_region  
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
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m s3_copy_files -f ${local.s3_files_json_path} -b ${data.amazon-parameterstore.s3_repository.value}"
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
        local.s3_files_json_path, 
        { 
          s3bucket = data.amazon-parameterstore.s3_repository.value, 
          region = data.amazon-parameterstore.s3_region.value
        }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-enterprise-base/image/${var.arcgis_version}/${var.os}/s3files -b ${data.amazon-parameterstore.s3_logs.value} -e 1200"
  }

  # Install
  provisioner "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
      JSON_ATTRIBUTES = base64encode(jsonencode({
        java = {
          version = "${var.java_version}.1+1"
          tarball_path = "/opt/software/archives/jdk-${var.java_version}.tar.gz"
        }
        tomcat = {
          version = var.tomcat_version
          tarball_path = "/opt/software/archives/apache-tomcat-${var.tomcat_version}.tar.gz"
          install_path = "/opt/tomcat_arcgis_${var.tomcat_version}"
        }
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          repository = {
            archives = "/opt/software/archives"
            setups = "/opt/software/setups"
          }
          web_server = {
            webapp_dir = "/opt/tomcat_arcgis_${var.tomcat_version}/webapps"
          }
          server = {
            install_dir = "/opt"
            configure_autostart = true
            install_system_requirements = true
            wa_name = "server"
          }
          web_adaptor = {
            install_dir = "/opt"
          }
          data_store = {
            install_dir = "/opt"
            setup_options = "-f Relational,TileCache"
            data_dir = "/gisdata/arcgisdatastore"
            configure_autostart = true
            preferredidentifier = "ip"
            install_system_requirements = true
          }
          portal = {
            install_dir = "/opt"
            configure_autostart = true
            install_system_requirements = true
            wa_name = "portal"
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::system]",
          "recipe[esri-tomcat::openjdk]",
          "recipe[esri-tomcat]",
          "recipe[arcgis-enterprise::install_portal]",
          "recipe[arcgis-enterprise::start_portal]",
          "recipe[arcgis-enterprise::webstyles]",
          "recipe[arcgis-enterprise::install_portal_wa]",
          "recipe[arcgis-enterprise::install_server]",
          "recipe[arcgis-enterprise::start_server]",
          "recipe[arcgis-enterprise::install_server_wa]",
          "recipe[arcgis-enterprise::install_datastore]",
          "recipe[arcgis-enterprise::start_datastore]"
        ]
      }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-enterprise-base/image/${var.arcgis_version}/${var.os}/install -b ${data.amazon-parameterstore.s3_logs.value} -e 3600"
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
            patches = "/opt/software/archives/patches"
          }
          portal = {
            install_dir = "/opt"
            patches = var.arcgis_portal_patches
          }
          server = {
            install_dir = "/opt"
            patches = var.arcgis_server_patches
          }
          data_store = {
            install_dir = "/opt"
            patches = var.arcgis_data_store_patches
          }
          web_adaptor = {
            install_dir = "/opt"
            patches = var.arcgis_web_adaptor_patches
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::install_patches]"
        ]
      }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-enterprise-base/image/${var.arcgis_version}/${var.os}/patches -b ${data.amazon-parameterstore.s3_logs.value} -e 3600"
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

  # Retrive the the AMI Id from packer-manifest.json manifest file and save it in SSM parameter.
  post-processor "shell-local" {
    env = {
      AWS_DEFAULT_REGION = var.aws_region
    }

    command = "python -m publish_artifact -p /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id} -f packer-manifest.json -r ${build.PackerRunUUID}"
  }
}
