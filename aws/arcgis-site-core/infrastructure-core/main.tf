/**
 * # Terraform module infrastructure-core
 *
 * Terraform module creates the networking, storage, and identity AWS resources shared across multiple deployments of an ArcGIS Enterprise site.
 * 
 * The module also looks up the latest public AMIs for the specified operating systems and stores the AMI IDs in SSM parameters.
 *
 * ![Core Infrastructure Resources](infrastructure-core.png "Core Infrastructure Resources")
 *
 * Public subnets are routed to the Internet gateway, private subnets to the NAT gateway, and isolated subnets to the VPC endpoints.
 * 
 * Ids of the created AWS resources are stored in SSM parameters:
 *
 * | SSM parameter name | Description |
 * | --- | --- |
 * | /arcgis/${var.site_id}/vpc/id | VPC Id of ArcGIS Enterprise site |
 * | /arcgis/${var.site_id}/vpc/hosted-zone-id | Private hosted zone Id of ArcGIS Enterprise site |
 * | /arcgis/${var.site_id}/vpc/isolated-subnet-<N> | Id of isolated VPC subnet <N> |
 * | /arcgis/${var.site_id}/vpc/private-subnet-<N> | Id of private VPC subnet <N> |
 * | /arcgis/${var.site_id}/vpc/public-subnet-<N> | Id of public VPC subnet <N> |
 * | /arcgis/${var.site_id}/iam/instance-profile-name | Name of IAM instance profile |
 * | /arcgis/${var.site_id}/s3/region | S3 buckets region code |
 * | /arcgis/${var.site_id}/s3/repository | S3 bucket of private repository |
 * | /arcgis/${var.site_id}/s3/backup | S3 bucket used by deployments to store backup data |
 * | /arcgis/${var.site_id}/s3/logs | S3 bucket used by deployments to store logs |
 * | /arcgis/${var.site_id}/images/${os} | Ids of the latest AMI for the operating systems |
 *
 * ## Requirements
 * 
 *  On the machine where Terraform is executed:
 *
 * * AWS credentials must be configured.
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable.
 */

terraform {
  backend "s3" {
    key = "arcgis-enterprise/aws/infrastructure-core.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.22"
    }
  }

  required_version = ">= 1.1.9"
}

provider "aws" {
  default_tags {
    tags = {
      ArcGISSiteId = var.site_id
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
  is_gov_cloud = contains(["us-gov-east-1", "us-gov-west-1"], data.aws_region.current.name)
  arn_identifier = local.is_gov_cloud ? "aws-us-gov" : "aws"
}
