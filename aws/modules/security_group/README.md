<!-- BEGIN_TF_DOCS -->
# Terraform module security_group

Terraform module creates and configures EC2 security group for deployment.

The module configures the following ingress rules:
- Allows the security group access to itself on all TCP ports,
- Allows access from Application Load Balancer's security group specified by alb_security_group_id variable to TCP ports specified by alb_ports variable,

The module allows egress for all ports on all IP addresses.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.allow_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.allow_self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alb_ports | Ports used by Application Load Balancer | `list(number)` | ```[ 80, 443 ]``` | no |
| alb_security_group_id | Security group Id of Application Load Balancer | `string` | n/a | yes |
| name | Security group name | `string` | n/a | yes |
| vpc_id | VPC Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | Security group Id |
<!-- END_TF_DOCS -->