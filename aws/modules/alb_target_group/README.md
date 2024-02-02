# Terraform module alb_target_group

The module creates Application Load Balancer target group for specific port and protocol, attaches specific instances to it, and adds the target group to the load balancer. The target group is configured to forward requests for specific path patterns.

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_lb_listener_rule.listener_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.target_group_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_listener.listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_listener) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_arn"></a> [alb\_arn](#input\_alb\_arn) | Application Load Balancer ARN | `string` | n/a | yes |
| <a name="input_alb_port"></a> [alb\_port](#input\_alb\_port) | Target group port | `number` | `80` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check path | `string` | `"/server/rest/info/healthcheck"` | no |
| <a name="input_instance_port"></a> [instance\_port](#input\_instance\_port) | Instance port | `number` | `80` | no |
| <a name="input_name"></a> [name](#input\_name) | Target group name | `string` | n/a | yes |
| <a name="input_path_patterns"></a> [path\_patterns](#input\_path\_patterns) | Listener rule path patterns | `list(string)` | <pre>[<br>  "/portal",<br>  "/portal/*",<br>  "/server",<br>  "/server/*"<br>]</pre> | no |
| <a name="input_protocol"></a> [protocol](#input\_protocol) | Target group protocol | `string` | `"HTTP"` | no |
| <a name="input_target_instances"></a> [target\_instances](#input\_target\_instances) | List of target EC2 instance Ids | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Application load balancer target group name |

<!-- BEGIN_TF_DOCS -->
# Terraform module alb_target_group

The module creates Application Load Balancer target group for specific port and protocol,
attaches specific EC2 instances to it, and adds the target group to the load balancer.
The target group is configured to forward requests for specific path patterns.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_lb_listener_rule.listener_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.target_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.target_group_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_listener.listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_listener) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alb_arn | Application Load Balancer ARN | `string` | n/a | yes |
| alb_port | Target group port | `number` | `80` | no |
| health_check_path | Health check path | `string` | `"/server/rest/info/healthcheck"` | no |
| instance_port | Instance port | `number` | `80` | no |
| name | Target group name | `string` | n/a | yes |
| path_patterns | Listener rule path patterns | `list(string)` | ```[ "/portal", "/portal/*", "/server", "/server/*" ]``` | no |
| priority | Target group priority | `number` | `100` | no |
| protocol | Target group protocol | `string` | `"HTTP"` | no |
| target_instances | List of target EC2 instance Ids | `list(string)` | n/a | yes |
| vpc_id | VPC Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| arn | Target group ARN |
| name | Application load balancer target group name |
<!-- END_TF_DOCS -->