<!-- BEGIN_TF_DOCS -->
# Terraform module ebs-csi-driver

The module installs Amazon EBS CSI Driver add-on to EKS cluster.

See: https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html

## Requirements

On the machine where terraform is executed must be installed AWS CLI and kubectl.

## Providers

| Name | Version |
|------|---------|
| aws | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_eks_addon.aws_ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) | resource |
| [aws_iam_role.aws_ebs_csi_driver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.aws_ebs_csi_driver_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [null_resource.storage_class](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.update_kubeconfig](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | The name of the EKS cluster | `string` | n/a | yes |
| oidc_arn | The OIDC provider ARN for the EKS cluster | `string` | n/a | yes |
<!-- END_TF_DOCS -->