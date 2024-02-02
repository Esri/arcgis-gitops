
# Create S3 bucket for the site's deployment repository
resource "aws_s3_bucket" "repository" {
  bucket = "${var.site_id}-repository-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = true
}

# Create S3 bucket for the site's backup data
resource "aws_s3_bucket" "backup" {
  bucket = "${var.site_id}-backup-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = true
}

# Create S3 bucket for the site's backup data
resource "aws_s3_bucket" "logs" {
  bucket = "${var.site_id}-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  force_destroy = true
}
