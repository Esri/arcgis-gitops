<!-- BEGIN_TF_DOCS -->
# Terraform Module K8s-cluster

The Terraform module provisions Amazon Elastic Kubernetes Service (EKS) cluster
that meets [ArcGIS Enterprise on Kubernetes system requirements](https://enterprise-k8s.arcgis.com/en/latest/deploy/configure-aws-for-use-with-arcgis-enterprise-on-kubernetes.htm).

The module installs the following add-ons to the EKS cluster:

* Load Balancer Controller add-on
* Amazon EBS CSI Driver add-on
* Amazon CloudWatch Observability EKS add-on

Optionally, the module also configures pull through cache rules for Amazon Elastic Container Registry (ECR)
to sync the contents of source Docker Hub and Public Amazon ECR registries with private Amazon ECR registry.

## Requirements

On the machine where Terraform is executed:

* AWS credentials and default region must be configured.
* AWS CLI, kubectl, and helm must be installed.

## SSM Parameters

If subnet IDs of the EKS cluster and node groups are not specified by input variables,
the subnet IDs are retrieved from the following SSM parameters:

| SSM parameter name | Description |
|--------------------|-------------|
| /arcgis/${var.site_id}/vpc/public-subnet-* | Public VPC subnets Ids |
| /arcgis/${var.site_id}/vpc/private-subnet-* | Private VPC subnets Ids |
| /arcgis/${var.site_id}/vpc/internal-subnet-* | Internal VPC subnets Ids |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.22 |
| tls | ~> 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| cloudwatch_observability | ./modules/cloudwatch-observability | n/a |
| ebs_csi_driver | ./modules/ebs-csi-driver | n/a |
| load_balancer_controller | ./modules/load-balancer-controller | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.containerinsights](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecr_pull_through_cache_rule.docker_hub](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_ecr_pull_through_cache_rule.public_ecr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_pull_through_cache_rule) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group.node_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_iam_openid_connect_provider.eks_oidc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.eks_cluster_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.eks_worker_node_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_kms_key.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_launch_template.node_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_secretsmanager_secret.aws_ecrpullthroughcache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.aws_ecrpullthroughcache](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.internal_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.public_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [tls_certificate.cluster](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/data-sources/certificate) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aws_region | AWS region Id | `string` | n/a | yes |
| container_registry_password | Source container registry user password | `string` | `null` | no |
| container_registry_url | Source container registry URL | `string` | `"registry-1.docker.io"` | no |
| container_registry_user | Source container registry user name | `string` | `null` | no |
| containerinsights_log_retention | The number of days to retain CloudWatch Container Insights log events | `number` | `90` | no |
| ecr_repository_prefix | The repository name prefix to use when caching images from the source registry | `string` | `"docker-hub"` | no |
| eks_version | The desired Kubernetes version for the EKS cluster | `string` | `"1.28"` | no |
| enable_waf | Enable WAF and Shield addons for ALB | `bool` | `true` | no |
| key_name | EC2 key pair name | `string` | `null` | no |
| node_groups | <p>EKS node groups configuration properties:</p>   <ul>   <li>name - Name of the node group</li>   <li>instance_type -Type of EC2 instance to use for the node group</li>   <li>root_volume_size - Size of the root volume in GB</li>   <li>desired_size - Number of nodes to start with</li>   <li>max_size - Maximum number of nodes in the node group</li>   <li>min_size - Minimum number of nodes in the node group</li>   <li>subnet_ids - List of subnet IDs to use for the node group (the first two private subnets are used by default)</li>   </ul> | ```list(object({ name = string instance_type = string root_volume_size = number desired_size = number max_size = number min_size = number subnet_ids = list(string) }))``` | ```[ { "desired_size": 4, "instance_type": "m6i.2xlarge", "max_size": 8, "min_size": 4, "name": "default", "root_volume_size": 1024, "subnet_ids": [] } ]``` | no |
| pull_through_cache | Configure ECR pull through cache rules | `bool` | `true` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis-enterprise"` | no |
| subnet_ids | EKS cluster subnet IDs (by default, the first two public, two private, and two internal VPC subnets are used) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| aws_region | AWS region |
| cluster_endpoint | EKS cluster endpoint |
| cluster_name | EKS cluster name |
| oidc_arn | EKS cluster OIDC provider ARN |
<!-- END_TF_DOCS -->