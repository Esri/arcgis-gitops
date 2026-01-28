<!-- BEGIN_TF_DOCS -->
# Ingress Monitoring Terraform Module

The module creates Monitoring Subsystem for the ArcGIS Enterprise on Kubernetes cluster-level ingress that includes:

* A CloudWatch alarm that monitors the ingress ALB target groups and post to the site alarms SNS topic if the number of unhealthy instances is nonzero.
* A CloudWatch dashboard that displays the CloudWatch alarm status, ALB metrics, and log of requests flagged by WAF rules.

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
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alb_arn | ARN of the Application Load Balancer | `string` | n/a | yes |
| namespace | Deployment namespace | `string` | n/a | yes |
| sns_topic_arn | SNS topic ARN for alarms | `string` | n/a | yes |
| waf_log_group | WAF log group name | `string` | n/a | yes |
<!-- END_TF_DOCS -->