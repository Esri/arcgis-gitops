/**
 * # Terraform module cloudwatch-observability
 * 
 * The module installs the Amazon CloudWatch Observability EKS add-on.
 *
 * See: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-addon.html
 */

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
