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

# Create S3 bucket for the site's deployment repository
resource "aws_s3_bucket" "repository" {
  bucket        = "${var.site_id}-repository-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  force_destroy = true
}

# Create S3 bucket for the site's backup data
resource "aws_s3_bucket" "backup" {
  bucket        = "${var.site_id}-backup-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  force_destroy = true
}

# Create S3 bucket for the site's backup data
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.site_id}-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  force_destroy = true
}

# Attach a bucket policy that grants ELB permission to write the access logs to the bucket.

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:${local.arn_identifier}:s3:::${aws_s3_bucket.logs.bucket}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      }
    ]
  })
}

# Create a backup vault for the site's infrastructure
resource "aws_backup_vault" "site" {
  name          = var.site_id
  force_destroy = true
}
