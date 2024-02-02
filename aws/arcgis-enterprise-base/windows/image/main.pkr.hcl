/**
 * # Packer Template for Base ArcGIS Enterprise AMIs
 * 
 * The Packer templates builds "main" and "fileserver" EC2 AMIs for a specific base ArcGIS Enterprise deployment.
 * 
 * The AMIs are built from a Windows OS base image specified by SSM parameter "/arcgis/${var.site_id}/images/${var.os}".
 * 
 * The template first copies installation media for the ArcGIS Enterprise version 
 * and required third party dependencies from My Esri and public repositories 
 * to the private repository S3 bucket. The files to copy are specified 
 * in ../config/arcgis-enterprise-s3files-${var.arcgis_version}.json index file.
 * 
 * Then the template uses python scripts to run SSM commands on the source EC2 instances.
 * 
 * On "main" instance:
 * 
 * 1. Install AWS CLI
 * 2. Install CloudWatch Agent
 * 3. Install Cinc Client and Chef Cookbooks for ArcGIS
 * 4. Download setups from the private repository S3 bucket.
 * 5. Install base ArcGIS Enterprise applications
 * 6. Install patches for the base ArcGIS Enterprise applications
 * 7. Delete unused files, uninstall Cinc Client, run sysprep
 * 
 * On "fileserver" instance:
 * 
 * 1. Install AWS CLI
 * 2. Install CloudWatch Agent
 * 3. Delete unused files, uninstall Cinc Client, run sysprep
 * 
 * Ids of "main" and "fileserver" AMIs are saved in "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/main" and "/arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/fileserver" SSM parameters.
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

data "amazon-parameterstore" "chef_client_url" {
  name  = "/arcgis/${var.site_id}/chef-client-url/${var.os}"
}

data "amazon-parameterstore" "chef_cookbooks_url" {
  name  = "/arcgis/${var.site_id}/cookbooks-url"
}

locals {
  index_file_path =  "${path.root}/../config/arcgis-enterprise-s3files-${var.arcgis_version}.json"

  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  
  main_machine_role = "packer-main"
  main_ami_name  = "arcgis-enterprise-base-${var.arcgis_version}-${var.os}-${local.timestamp}"
  main_ami_description = "Base ArcGIS Enterprise ${var.arcgis_version} AMI for ${var.os}"
  
  fileserver_machine_role = "packer-fileserver"
  fileserver_ami_name  = "arcgis-enterprise-base-fileserver-${var.os}-${local.timestamp}"
  fileserver_ami_description = "Base ArcGIS Enterprise fileserver AMI for ${var.os}"

  software_dir = "C:/Software/*"

  # Platform-specific attributes

  chef_client_url = "{{ssm:/arcgis/${var.site_id}/chef-client-url/${var.os}}}"

  # ArcGIS version-specific attributes
  dotnet_setup_path = {
    "11.0" = null
    "11.1" = "C:\\Software\\Archives\\dotnet-hosting-win.exe"
    "11.2" = "C:\\Software\\Archives\\dotnet-hosting-win.exe"
  }

  web_deploy_setup_path = {
    "11.0" = null
    "11.1" = "C:\\Software\\Archives\\WebDeploy_amd64_en-US.msi"
    "11.2" = "C:\\Software\\Archives\\WebDeploy_amd64_en-US.msi"
  }
}

source "amazon-ebs" "main" {
  ami_name      = local.main_ami_name
  ami_description = local.main_ami_description
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
    Name = local.main_ami_name
    ArcGISSiteId = var.site_id    
    ArcGISVersion = var.arcgis_version
    ArcGISDeploymentId = var.deployment_id    
    ArcGISMachineRole = local.main_machine_role
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
  name = "${var.deployment_id}-main"
 
  sources = [
    "source.amazon-ebs.main"
  ]

  # Copy files to private S3 repository
  provisioner "shell-local" {
    command = "python -m s3_copy_files -f ${local.index_file_path} -u ${var.arcgis_online_username} -p ${var.arcgis_online_password} -b ${data.amazon-parameterstore.s3_repository.value}"
  }

  # Install AWS CLI
  provisioner "shell-local" {
    command = "python -m ssm_install_awscli -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Install CloudWatch Agent
  provisioner "shell-local" {
    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Bootstrap
  provisioner "shell-local" {
    command = "python -m ssm_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -c ${data.amazon-parameterstore.chef_client_url.value} -k ${data.amazon-parameterstore.chef_cookbooks_url.value} -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Download setups
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(templatefile(
        local.index_file_path, 
        { 
          s3bucket = data.amazon-parameterstore.s3_repository.value, 
          region = data.amazon-parameterstore.s3_region.value
        }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-enterprise-base/image/${var.arcgis_version}/${var.os}/s3files -b ${data.amazon-parameterstore.s3_logs.value} -e 1200"
  }

  # Install
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          run_as_password = var.run_as_password
          configure_windows_firewall = true
          repository = {
            archives = "C:\\Software\\Archives"
            setups = "C:\\Software\\Setups"
          }
          server = {
            install_dir = "C:\\Program Files\\ArcGIS\\Server"
            install_system_requirements = true
            wa_name = "server"
          }
          web_adaptor = {
            install_system_requirements = true
            dotnet_setup_path = local.dotnet_setup_path[var.arcgis_version]
            web_deploy_setup_path = local.web_deploy_setup_path[var.arcgis_version]
            admin_access = true
            reindex_portal_content = false
          }
          data_store = {
            install_dir = "C:\\Program Files\\ArcGIS\\DataStore"
            setup_options = "ADDLOCAL=relational,tilecache"
            data_dir = "C:\\arcgisdatastore"
            install_system_requirements = true
            preferredidentifier = "hostname"
          }
          portal = {
            install_dir = "C:\\Program Files\\ArcGIS\\Portal"
            install_system_requirements = true
            data_dir = "C:\\arcgisportal"
            wa_name = "portal"
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::system]",
          "recipe[esri-iis::install]",
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

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-enterprise-base/image/${var.arcgis_version}/${var.os}/install -b ${data.amazon-parameterstore.s3_logs.value} -e 3600"
  }

  # Install patches
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version = var.arcgis_version
          repository = {
            patches = "C:\\Software\\Archives"
          }
          portal = {
            patches = var.arcgis_portal_patches
          }
          server = {
            patches = var.arcgis_server_patches
          }
          data_store = {
            patches = var.arcgis_data_store_patches
          }
          web_adaptor = {
            patches = var.arcgis_web_adaptor_patches
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::install_patches]"
        ]
      }))
    }

    command = "python -m ssm_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -j /arcgis/${var.site_id}/attributes/arcgis-enterprise-base/image/${var.arcgis_version}/${var.os}/patches -b ${data.amazon-parameterstore.s3_logs.value} -e 1200"
  }

  # Clean up
  provisioner "shell-local" {
    command = "python -m ssm_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${local.main_machine_role} -p true -f \"${local.software_dir},C:/Program Files/ArcGIS/Portal/etc/ssl/*\" -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Save the build artifacts metadata in packer-manifest.json file.
  # Note: New builds add new artifacts to packer-manifest.json file.
  post-processor "manifest" {
    output = "main-packer-manifest.json"
    strip_path = true
    custom_data = {
      ami_description = local.main_ami_description
    }
  }

  # Retrive the the AMI Id from main-packer-manifest.json manifest file and save it in SSM parameter.
  post-processor "shell-local" {
    command = "python -m publish_artifact -p /arcgis/${var.site_id}/images/${var.os}/${var.deployment_id}/main -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }
}

build {
  name = "${var.deployment_id}-fileserver"
 
  sources = [
    "source.amazon-ebs.fileserver"
  ]

  # Install AWS CLI
  provisioner "shell-local" {
    command = "python -m ssm_install_awscli -s ${var.site_id} -d ${var.deployment_id} -m ${local.fileserver_machine_role} -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # Install CloudWatch Agent
  provisioner "shell-local" {
    command = "python -m ssm_package -s ${var.site_id} -d ${var.deployment_id} -m ${local.fileserver_machine_role} -p AmazonCloudWatchAgent -b ${data.amazon-parameterstore.s3_logs.value}"
  }

  # sysprep
  provisioner "shell-local" {
    command = "python -m ssm_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${local.fileserver_machine_role} -p true -f \"\" -b ${data.amazon-parameterstore.s3_logs.value}"
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
