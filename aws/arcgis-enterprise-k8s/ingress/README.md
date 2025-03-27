<!-- BEGIN_TF_DOCS -->
# Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes

This module provisions a Kubernetes namespace for ArcGIS Enterprise on
Kubernetes deployment in Amazon Elastic Kubernetes Service (EKS) cluster and
a cluster-level ingress controller that routes traffic to the deployment.

See: https://enterprise-k8s.arcgis.com/en/latest/deploy/use-a-cluster-level-ingress-controller-with-eks.htm

If a Route 53 hosted zone ID is provided, a CNAME record is created in the hosted zone
that points the deployment's FQDN to the load balancer's DNS name.

## Requirements

On the machine where Terraform is executed:

* AWS credentials must be configured.
* EKS cluster configuration information must be provided in ~/.kube/config file.

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.22 |
| kubernetes | ~> 2.26 |

## Resources

| Name | Type |
|------|------|
| [aws_route53_record.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [kubernetes_ingress_v1.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/ingress_v1) | resource |
| [kubernetes_namespace.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_enterprise_context | Context path to be used in the URL for ArcGIS Enterprise on Kubernetes | `string` | `"arcgis"` | no |
| aws_region | AWS region Id | `string` | n/a | yes |
| deployment_fqdn | The fully qualified domain name (FQDN) to access ArcGIS Enterprise on Kubernetes | `string` | n/a | yes |
| deployment_id | ArcGIS Enterprise deployment Id | `string` | `"enterprise-k8s"` | no |
| hosted_zone_id | The Route 53 hosted zone ID for the domain | `string` | `null` | no |
| internal_load_balancer | If true, the load balancer scheme is set to 'internal' | `bool` | `false` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |
| ssl_certificate_arn | SSL certificate ARN for HTTPS listeners of the load balancer | `string` | n/a | yes |
| ssl_policy | Security Policy that should be assigned to the ALB to control the SSL protocol and ciphers | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_dns_name | DNS name of the load balancer |
<!-- END_TF_DOCS -->