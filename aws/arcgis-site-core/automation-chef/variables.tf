variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "images" {
  description = "AMI search filters by operating  system"
  type        = map(any)
  default = {
    windows2022 = {
      ami_name_filter = "Windows_Server-2022-English-Full-Base-*",
      owner           = "801119661308", #Amazon
      description     = "Microsoft Windows Server 2022 Full Locale English AMI"
    }
    ubuntu20 = {
      ami_name_filter : "ubuntu/images/hvm-ssd/ubuntu-*20*-amd64-server-*",
      owner : "099720109477", # Canonical
      description : "Canonical, Ubuntu, 20.04 LTS, amd64 focal image"
    }
    ubuntu22 = {
      ami_name_filter : "ubuntu/images/hvm-ssd/ubuntu-*22*-amd64-server-*",
      owner : "099720109477", # Canonical
      description : "Canonical, Ubuntu, 22.04 LTS, amd64 focal image"
    }
    rhel8 = {
      ami_name_filter : "RHEL-8.6.0_HVM-*-x86_64-*-Hourly2-GP2",
      owner : "309956199498", # Red Hat
      description : "Red Hat Enterprise Linux version 8 (HVM), EBS General Purpose (SSD) Volume Type"
    }
    rhel9 = {
      ami_name_filter : "RHEL-9.3.0_HVM-*-x86_64-*-Hourly2-GP2",
      owner : "309956199498", # Red Hat
      description : "Red Hat Enterprise Linux version 9 (HVM), EBS General Purpose (SSD) Volume Type"
    }
    sles15 = {
      ami_name_filter : "suse-sles-15-*-v*-hvm-ssd-x86_64",
      owner : "013907871322", # Amazon
      description : "SUSE Linux Enterprise Server 15 (HVM, 64-bit, SSD-Backed)"
    }
  }
}

variable "chef_client_paths" {
  description = "Chef/CINC Client setup S3 keys by operating system"
  type        = map(any)
  default = {
    windows2022 = {
      path        = "cinc/cinc-18.4.2-1-x64.msi"
      description = "Chef Client setup S3 key for Microsoft Windows Server 2022"
    }
    ubuntu20 = {
      path        = "cinc/cinc_18.4.2-1_amd64.deb"
      description = "Chef Client setup S3 key for Ubuntu 20.04 LTS"
    }
    ubuntu22 = {
      path        = "cinc/cinc_18.4.2-1_amd64.deb"
      description = "Chef Client setup S3 key for Ubuntu 22.04 LTS"
    }
    rhel8 = {
      path        = "cinc/cinc-18.4.2-1.el8.x86_64.rpm"
      description = "Chef Client setup S3 key for Red Hat Enterprise Linux version 8"
    }
    rhel9 = {
      path        = "cinc/cinc-18.4.2-1.el9.x86_64.rpm"
      description = "Chef Client setup S3 key for Red Hat Enterprise Linux version 9"
    }
    sles15 = {
      path        = "cinc/cinc-18.4.2-1.sles15.x86_64.rpm"
      description = "Chef Client setup S3 key for SUSE Linux Enterprise Server 15"
    }
  }
}

variable "arcgis_cookbooks_path" {
  description = "S3 repository key of Chef cookbooks for ArcGIS distribution archive in the repository bucket"
  type        = string
  default     = "cookbooks/arcgis-5.0.0-cookbooks.tar.gz"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()-]+(\\/[a-zA-Z0-9!_.*'()-]+)*$", var.arcgis_cookbooks_path))
    error_message = "The s3_key value must be in a valid S3 key format."
  }  
}
