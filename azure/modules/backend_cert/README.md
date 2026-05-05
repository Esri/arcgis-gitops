<!-- BEGIN_TF_DOCS -->
# Terraform module backend_cert

Creates an ArcGIS backend TLS certificate package by reading a CA private key and
root certificate from Azure Key Vault, issuing a leaf certificate for configured
Common Name, DNS and IP SANs, exporting a password-protected PFX with certificate chain, and
uploading the PFX to Azure Blob Storage.

## Requirements

On the machine where Terraform is executed:

* OpenSSL must be installed and available in the system PATH
* Azure credentials must be configured

## Key Vault Secrets

### Secrets Read by the Module

| Secret Name                      | Description |
|----------------------------------|-------------|
| ${var.ingress_id}-ca-private-key | PEM-encoded private key used to sign CSR and the backend certificate |
| ${var.ingress_id}-ca-root-cert   | PEM-encoded root certificate |

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| local | n/a |
| terraform | n/a |
| tls | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_storage_blob.pfx_cert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob) | resource |
| [local_file.full_chain](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_sensitive_file.private_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [terraform_data.generate_pfx](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [tls_cert_request.backend_leaf](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/cert_request) | resource |
| [tls_locally_signed_cert.backend_leaf](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/locally_signed_cert) | resource |
| [tls_private_key.csr_private_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azurerm_key_vault_secret.ca_private_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.ca_root_cert](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| common_name | Common Name (CN) to use in the certificate. | `string` | n/a | yes |
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| dns_names | List of DNS names to include as SANs in the certificate. | `list(string)` | `[]` | no |
| ingress_id | ingress ID. | `string` | `"enterprise-ingress"` | no |
| ip_addresses | List of IP addresses to include as SANs in the certificate. | `list(string)` | `[]` | no |
| key_vault_id | ID of the Key Vault where the trusted root certificate is stored. | `string` | n/a | yes |
| pfx_password | Password for the generated PFX file. | `string` | n/a | yes |
| storage_account_name | Name of the storage account where the backend certificate will be stored. | `string` | n/a | yes |
| storage_container_name | Name of the storage container where the backend certificate will be stored. | `string` | n/a | yes |
| validity_period_hours | Number of hours the generated backend certificate will be valid for. | `number` | `87600` | no |
<!-- END_TF_DOCS -->