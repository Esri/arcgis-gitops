<!-- BEGIN_TF_DOCS -->
# Terraform module load-balancer-controller

The module installs AWS Load Balancer Controller add-on to EKS cluster.

See: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

## Requirements

On the machine where terraform is executed must be installed AWS CLI, kubectl, helm, and Docker.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| local | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.locad_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.aws_eks_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_eks_load_balancer_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [local_file.service_account](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.copy_public_ecr_image](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.helm_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.service_account](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.update_kubeconfig](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| controller_version | Version of the controller | `string` | `"2.16.0"` | no |
| copy_image | If set to true, the controller's image is copied to the private ECR repository | `bool` | `false` | no |
| enable_waf | Enable WAF and Shield addons for ALB | `bool` | `true` | no |
| oidc_arn | OIDC provider ARN for the EKS cluster | `string` | n/a | yes |
| vpc_id | The ID of the VPC where the EKS cluster is deployed | `string` | n/a | yes |
<!-- END_TF_DOCS -->