/**
 * # Terraform module cloudwatch-observability
 * 
 * The module installs the Amazon CloudWatch Observability EKS add-on.
 *
 * See: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-addon.html
 */

# Pre-create CloudWatch log groups for the Amazon CloudWatch Observability EKS add-on.
# Note that the log groups created by CloudWatch agent on demand do not expire and 
# are not deleted when the the EKS cluster is deleted. 

resource "aws_cloudwatch_log_group" "containerinsights_application" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.log_retention
}

resource "aws_cloudwatch_log_group" "containerinsights_dataplane" {
  name              = "/aws/containerinsights/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention
}

resource "aws_cloudwatch_log_group" "containerinsights_host" {
  name              = "/aws/containerinsights/${var.cluster_name}/host"
  retention_in_days = var.log_retention
}

resource "aws_cloudwatch_log_group" "containerinsights_performance" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention
}

# Install the Amazon CloudWatch Observability EKS add-on.
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = var.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  configuration_values = jsonencode({
    containerLogs = {
       enabled = var.container_logs_enabled 
    } 
  })
}
