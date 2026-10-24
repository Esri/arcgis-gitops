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

terraform {
  backend "s3" {
    key = "arcgis-enterprise/aws/infrastructure-core.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }

  required_version = ">= 1.10.0"
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      ArcGISAutomation   = "arcgis-gitops"      
      ArcGISEnterpriseID = var.enterprise_id
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Look up the latest AMIs for the supported OSs

data "aws_ami" "os_image" {
  for_each = var.images

  most_recent = true

  filter {
    name   = "name"
    values = [var.images[each.key].ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.images[each.key].owner]
}

locals {
  is_gov_cloud = contains(["us-gov-east-1", "us-gov-west-1"], data.aws_region.current.region)
  arn_identifier = local.is_gov_cloud ? "aws-us-gov" : "aws"
}