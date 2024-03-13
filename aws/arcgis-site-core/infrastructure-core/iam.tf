# IAM role of the site's SSM managed EC2 instances
resource "aws_iam_role" "arcgis_enterprise_role" {
  name_prefix = "ArcGISEnterpriseRole"
  description = "Permissions required for SSM managed instances and ArcGIS Enterprise apps"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = ["ec2.amazonaws.com", "ssm.amazonaws.com"]
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  tags = {
    Name = "${var.site_id}/role"
  }
}

# IAM instance profile of the site's SSM managed EC2 instances
resource "aws_iam_instance_profile" "arcgis_enterprise_profile" {
  name_prefix = var.site_id
  role        = aws_iam_role.arcgis_enterprise_role.name
}
