<!-- BEGIN_TF_DOCS -->
# Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes

This module provisions a Kubernetes namespace for ArcGIS Enterprise on
Kubernetes deployment in Amazon Elastic Kubernetes Service (EKS) cluster and
an ingress resource that routes traffic to the deployment.

See: https://enterprise-k8s.arcgis.com/en/latest/deploy/use-a-cluster-level-ingress-controller-with-eks.htm

The module creates a Web Application Firewall (WAF) Web ACL and associates it with the ingress Application Load Balancer.
The Web ACL is configured with a set of managed rules to protect the load balancer from common web exploits.
The WAF mode can be set either to "detect" (default) or "protect".
In "detect" mode, the WAF only counts and logs the requests that match the rules,
while in "protect" mode, the WAF blocks the requests.

If enable_access_log is set to true, access logging is enabled for the load balancer. The access logs are stored
in the site's logs S3 bucket specified by the "/arcgis/${var.site_id}/s3/logs" SSM parameter.

If a Route 53 hosted zone ID is provided, an alias record is created in the hosted zone
that points the deployment's FQDN to the load balancer's DNS name. The DNS name is also stored in
"/arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name" SSM parameter.

The module also creates a private Route 53 hosted zone for the deployment FQDN and an alias record
in the hosted zone for the load balancer DNS name.
This makes the deployment FQDN always addressable from the VPC subnets.

The module creates a monitoring subsystem for the ingress that includes:

* A CloudWatch alarm that monitors the health of ingress ALB target groups and posts to the site alarms SNS topic if the number of unhealthy instances is nonzero
* A CloudWatch log group for AWS WAF logs
* A CloudWatch dashboard that displays the CloudWatch alarm status, the ALB metrics, and the log of requests flagged by WAF rules

## Requirements

On the machine where Terraform is executed:

* AWS credentials must be configured.
* EKS cluster configuration information must be provided in ~/.kube/config file.

## SSM Parameters

The module reads the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/s3/logs | S3 bucket used by deployments to store logs |
| /arcgis/${var.site_id}/sns-topics/site-alarms | Site alarms SNS topic ARN |
| /arcgis/${var.site_id}/vpc/id | VPC ID |

The module writes the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/${var.deployment_id}/alb/arn | ARN of the application load balancer |
| /arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name | DNS name of the application load balancer |
| /arcgis/${var.site_id}/${var.deployment_id}/deployment-fqdn | Fully qualified domain name of the site ingress |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.10 |
| kubernetes | ~> 2.26 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| monitoring | ./modules/monitoring | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.waf_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_route53_record.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.deployment_fqdn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.deployment_fqdn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_ssm_parameter.alb_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.alb_dns_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.deployment_fqdn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_wafv2_web_acl.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.waf_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |
| [kubernetes_ingress_v1.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_namespace.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [aws_lb.arcgis_enterprise_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_ssm_parameter.s3_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.sns_topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.vpc_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_enterprise_context | Context path to be used in the URL for ArcGIS Enterprise on Kubernetes | `string` | `"arcgis"` | no |
| aws_region | AWS region Id | `string` | n/a | yes |
| deployment_fqdn | The fully qualified domain name (FQDN) to access ArcGIS Enterprise on Kubernetes | `string` | n/a | yes |
| deployment_id | ArcGIS Enterprise deployment Id | `string` | `"enterprise-k8s"` | no |
| enable_access_log | Enable access logging for the load balancer | `bool` | `true` | no |
| hosted_zone_id | The Route 53 public hosted zone ID for the domain | `string` | `null` | no |
| internal_load_balancer | If true, the load balancer scheme is set to 'internal' | `bool` | `false` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |
| ssl_certificate_arn | SSL certificate ARN for HTTPS listeners of the load balancer | `string` | n/a | yes |
| ssl_policy | Security Policy that should be assigned to the ALB to control the SSL protocol and ciphers | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| waf_mode | Specifies the mode of the Web Application Firewall (WAF). Valid values are 'detect' and 'protect'. | `string` | `"detect"` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_arn | Application Load Balancer ARN |
| alb_dns_name | Application Load Balancer DNS name |
| alb_zone_id | Application Load Balancer zone ID |
<!-- END_TF_DOCS -->