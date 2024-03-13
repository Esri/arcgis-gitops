<!-- BEGIN_TF_DOCS -->
# Terraform Module K8s-cluster

The Terraform module provisions Amazon Elastic Kubernetes Service (EKS) cluster
that meets ArcGIS Enterprise on Kubernetes system requirements.

See: https://enterprise-k8s.arcgis.com/en/latest/deploy/configure-aws-for-use-with-arcgis-enterprise-on-kubernetes.htm

## Requirements

On the machine where Terraform is executed:

* AWS credentials and default region must be configured.
* AWS CLI, kubectl, and helm must be installed.

## SSM Parameters

The module uses the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/vpc/private-subnet-1 | Private VPC subnet 1 Id |
| /arcgis/${var.site_id}/vpc/private-subnet-2 | Private VPC subnet 2 Id |
| /arcgis/${var.site_id}/vpc/public-subnet-1 | Public VPC subnet 1 Id |
| /arcgis/${var.site_id}/vpc/public-subnet-2 | Public VPC subnet 2 Id |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.22 |
| tls | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| ebs_csi_driver | ./modules/ebs-csi-driver | n/a |
| load_balancer_controller | ./modules/load-balancer-controller | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.node_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_openid_connect_provider.eks_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_worker_node_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_kms_key.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_launch_template.node_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.private_subnet1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.private_subnet2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.public_subnet1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.public_subnet2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [tls_certificate.cluster](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| eks_version | The desired Kubernetes version for the EKS cluster | `string` | `"1.28"` | no |
| key_name | EC2 key pair name | `string` | `null` | no |
| node_groups | EKS Node Groups configuration | ```list(object({ name = string instance_type = string root_volume_size = number desired_size = number max_size = number min_size = number }))``` | ```[ { "desired_size": 3, "instance_type": "m6i.2xlarge", "max_size": 5, "min_size": 3, "name": "default", "root_volume_size": 1024 } ]``` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis-enterprise"` | no |

## Outputs

| Name | Description |
|------|-------------|
| aws_region | AWS region |
| cluster_endpoint | EKS cluster endpoint |
| cluster_name | EKS cluster name |
| oidc_arn | EKS cluster OIDC provider ARN |
<!-- END_TF_DOCS -->