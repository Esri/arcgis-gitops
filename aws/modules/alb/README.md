<!-- BEGIN_TF_DOCS -->
# Terraform module alb

The module creates and configures Application Load Balancer for a deployment.
It sets up a security group, HTTP and HTTPS listeners, and a default target group for the load balancer.
if the hosted zone ID and domain name are provided, the module also creates Route 53 records for the load balancer.
The load balancer is configured to redirect HTTP ports to HTTPS.
The security group Id and ARN of the load balancer are stored in SSM Parameter Store.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_lb.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.arcgis_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.arcgis_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.allow_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.allow_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ssm_parameter.alb_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.alb_security_group_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| client_cidr_blocks | Client CIDR blocks | `list(string)` | ```[ "0.0.0.0/0" ]``` | no |
| deployment_fqdn | Fully qualified domain name of the ArcGIS Server deployment | `string` | `null` | no |
| deployment_id | ArcGIS Server deployment Id | `string` | n/a | yes |
| hosted_zone_id | The Route 53 hosted zone ID for the deployment FQDN | `string` | `null` | no |
| http_ports | List of HTTP ports for the load balancer | `list(number)` | ```[ 80 ]``` | no |
| https_ports | List of HTTPS ports for the load balancer | `list(number)` | ```[ 443 ]``` | no |
| internal_load_balancer | If true, the load balancer scheme is set to 'internal' | `bool` | `false` | no |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
| ssl_certificate_arn | SSL certificate ARN for HTTPS listeners of the load balancer | `string` | n/a | yes |
| ssl_policy | Security Policy that should be assigned to the ALB to control the SSL protocol and ciphers | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| subnets | List of subnet IDs for the load balancer | `list(string)` | n/a | yes |
| vpc_id | VPC ID for the load balancer | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| alb_arn | Application Load Balancer ARN |
| alb_dns_name | Application Load Balancer DNS name |
| security_group_id | Application Load Balancer security group Id |
<!-- END_TF_DOCS -->