<!-- BEGIN_TF_DOCS -->
# Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes

This module manages the ingress resources for the deployment of ArcGIS Enterprise on Kubernetes:

1. Retrieves ID of the Application Gateway for Containers from "alb-id" secret of
   the site'ss Key Vault and creates frontend for the deployment in the load balancer.
2. Creates Kubernetes namespace for ArcGIS Enterprise on Kubernetes deployment in
   Azure Kubernetes Service (AKS) cluster.
3. Create a secret with the TLS certificate for the HTTPS listener.
4. Create a secret with the CA certificate for the backend TLS policy.
5. Creates a Kubernetes Gateway resource with HTTPS listener for the deployment frontend.
6. Creates a Kubernetes HTTPRoute resource that routes the gateway's traffic to
   port 443 of arcgis-ingress-nginx service.
7. Creates a Kubernetes BackendTLSPolicy resource required for the end-to-end HTTPS route.
8. Creates a Kubernetes HealthCheckPolicy resource for the gateway.

If hosted zone name is provided, a CNAME record is created in the hosted zone
that points the deployment's FQDN to the Application Gateway's frontend DNS name.

## Requirements

On the machine where Terraform is executed:

* Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID,
  and ARM_CLIENT_SECRET environment variables.
* AKS cluster configuration information must be provided in ~/.kube/config file.

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.16 |
| kubernetes | ~> 2.26 |

## Resources

| Name | Type |
|------|------|
| [azurerm_application_load_balancer_frontend.deployment_frontend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_load_balancer_frontend) | resource |
| [azurerm_dns_cname_record.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_cname_record) | resource |
| [kubernetes_manifest.gateway](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.health_check_policy](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.http_route](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.tls_policy](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.arcgis_enterprise](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.ca_bundle_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.listener_tls_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [azurerm_key_vault.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.alb_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_enterprise_context | Context path to be used in the URL for ArcGIS Enterprise on Kubernetes | `string` | `"arcgis"` | no |
| ca_certificate_path | File path to the CA certificate used to validate the backend TLS certificate | `string` | n/a | yes |
| deployment_fqdn | Fully qualified domain name (FQDN) to access ArcGIS Enterprise on Kubernetes | `string` | n/a | yes |
| deployment_id | ArcGIS Enterprise deployment Id | `string` | `"arcgis-enterprise-k8s"` | no |
| hosted_zone_name | Hosted zone name for the domain | `string` | `null` | no |
| hosted_zone_resource_group | Resource group name of the hosted zone | `string` | `null` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis-enterprise"` | no |
| tls_certificate_path | File path to the TLS certificate for the HTTPS listener | `string` | n/a | yes |
| tls_private_key_path | File path to the TLS certificate's private key for the HTTPS listener | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| alb_dns_name | FQDN of the Application Gateway frontend |
| deployment_url | URL of the ArcGIS Enterprise on Kubernetes deployment |
<!-- END_TF_DOCS -->