/**
 * # Terraform module infrastructure-core
 *
 * Terraform module creates the networking, storage, and identity AWS resource
 * shared across multiple deployments of an ArcGIS Enterprise site.
 *
 * ![Core Infrastructure Resources](images/infrastructure-core.png "Core Infrastructure Resources")
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
