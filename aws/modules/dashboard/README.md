<!-- BEGIN_TF_DOCS -->
# Terraform module dashboard

Terraform module dashboard creates AWS resources for the deployment monitoring subsystem:

* CloudWatch alarms for unhealthy EC2 instances,
* SNS topic used by the alarms, and
* CloudWatch dashboard.

The CloudWatch dashboard includes widgets for:

* CloudWatch alarms,
* Healthy host count in the ALB target groups,
* CPU, memory, disk, and network utilization of the deployment's EC2 instances,
* System and Chef logs of the deployment EC2 instances.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_dashboard.dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_metric_alarm.unhealthy_alb_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_sns_topic.deployment_alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_ssm_parameter.sns_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alb_arn | ARN of Application Load Balancer | `string` | `null` | no |
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| log_group_name | CloudWatch log group name | `string` | n/a | yes |
| platform | Deployment platform (windows\|linux) | `string` | `"windows"` | no |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->