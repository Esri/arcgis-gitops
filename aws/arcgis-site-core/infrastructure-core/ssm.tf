
# Add parameters to SSM Parameter Store

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/arcgis/${var.site_id}/vpc/id"
  type  = "String"
  value = aws_vpc.vpc.id
  description = "VPC Id of ArcGIS Enterprise site '${var.site_id}'"
}

resource "aws_ssm_parameter" "hosted_zone_id" {
  name  = "/arcgis/${var.site_id}/vpc/hosted-zone-id"
  type  = "String"
  value = aws_route53_zone.private.id
  description = "Private hosted zone Id of ArcGIS Enterprise site '${var.site_id}'"
}

resource "aws_ssm_parameter" "isolated_subnet_1" {
  count = var.isolated_subnets ? 1 : 0
  name  = "/arcgis/${var.site_id}/vpc/isolated-subnet-1"
  type  = "String"
  value = aws_subnet.isolated_subnet_1[0].id
  description = "Id of isolated VPC subnet 1"
}

resource "aws_ssm_parameter" "isolated_subnet_2" {
  count = var.isolated_subnets ? 1 : 0
  name  = "/arcgis/${var.site_id}/vpc/isolated-subnet-2"
  type  = "String"
  value = aws_subnet.isolated_subnet_2[0].id
  description = "Id of isolated VPC subnet 2"
}

resource "aws_ssm_parameter" "private_subnet_1" {
  name  = "/arcgis/${var.site_id}/vpc/private-subnet-1"
  type  = "String"
  value = aws_subnet.private_subnet_1.id
  description = "Id of private VPC subnet 1"
}

resource "aws_ssm_parameter" "private_subnet_2" {
  name  = "/arcgis/${var.site_id}/vpc/private-subnet-2"
  type  = "String"
  value = aws_subnet.private_subnet_2.id
  description = "Id of private VPC subnet 2"
}

resource "aws_ssm_parameter" "public_subnet_1" {
  name  = "/arcgis/${var.site_id}/vpc/public-subnet-1"
  type  = "String"
  value = aws_subnet.public_subnet_1.id
  description = "Id of public VPC subnet 1"
}

resource "aws_ssm_parameter" "public_subnet_2" {
  name  = "/arcgis/${var.site_id}/vpc/public-subnet-2"
  type  = "String"
  value = aws_subnet.public_subnet_2.id
  description = "Id of public VPC subnet 2"
}

resource "aws_ssm_parameter" "instance_profile_name" {
  name  = "/arcgis/${var.site_id}/iam/instance-profile-name"
  type  = "String"
  value = aws_iam_instance_profile.arcgis_enterprise_profile.name
  description = "Name of IAM instance profile"
}

resource "aws_ssm_parameter" "s3_repository" {
  name  = "/arcgis/${var.site_id}/s3/repository"
  type  = "String"
  value = aws_s3_bucket.repository.bucket
  description = "S3 bucket of private repository"
}

resource "aws_ssm_parameter" "s3_backup" {
  name  = "/arcgis/${var.site_id}/s3/backup"
  type  = "String"
  value = aws_s3_bucket.backup.bucket
  description = "S3 bucket used by deployments to store backup data"
}

resource "aws_ssm_parameter" "s3_logs" {
  name  = "/arcgis/${var.site_id}/s3/logs"
  type  = "String"
  value = aws_s3_bucket.logs.bucket
  description = "S3 bucket used by deployments to store logs"
}

resource "aws_ssm_parameter" "s3_region" {
  name  = "/arcgis/${var.site_id}/s3/region"
  type  = "String"
  value = data.aws_region.current.id
  description = "S3 buckets region code"
}
