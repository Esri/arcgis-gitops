<!-- BEGIN_TF_DOCS -->
# Terraform module cloudwatch-observability

The module installs the Amazon CloudWatch Observability EKS add-on.

See: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-EKS-addon.html

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.cloudwatch_observability](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | The name of the EKS cluster | `string` | n/a | yes |
| container_logs_enabled | Whether to enable container logs | `bool` | `true` | no |
<!-- END_TF_DOCS -->