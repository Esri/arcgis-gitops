<!-- BEGIN_TF_DOCS -->
# Terraform module monitoring

The module creates Monitoring Subsystem for the ArcGIS Enterprise on Kubernetes deployment.

The Monitoring Subsystem consists of:
An SNS topic with a subscription for the primary site administrator.
A CloudWatch alarm that monitors the ingress ALB target groups and post to the SNS topic if the number of unhealthy instances in nonzero.
A CloudWatch dashboard that displays the CloudWatch alerts, metrics, and container logs of the deployment.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_composite_alarm.unhealthy_alb_targets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_composite_alarm) | resource |
| [aws_cloudwatch_dashboard.dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_metric_alarm.unhealthy_alb_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_sns_topic.deployment_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_subscription.infrastructure_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_lb.arcgis_enterprise_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_email | ArcGIS Enterprise on Kubernetes organization administrator account email | `string` | n/a | yes |
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| namespace | Deployment namespace | `string` | n/a | yes |
<!-- END_TF_DOCS -->