/*
 * # Terraform module backend_cert
 *
 * Creates an ArcGIS backend TLS certificate package by reading a CA private key and
 * root certificate from Azure Key Vault, issuing a leaf certificate for configured
 * Common Name, DNS and IP SANs, exporting a password-protected PFX with certificate chain, and
 * uploading the PFX to Azure Blob Storage.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * OpenSSL must be installed and available in the system PATH
 * * Azure credentials must be configured
 * 
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 *
 * | Secret Name                      | Description |
 * |----------------------------------|-------------|
 * | ${var.ingress_id}-ca-private-key | PEM-encoded private key used to sign CSR and the backend certificate |
 * | ${var.ingress_id}-ca-root-cert   | PEM-encoded root certificate |
 */

# Copyright 2026 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "azurerm_key_vault_secret" "ca_private_key" {
  name         = "${var.ingress_id}-ca-private-key"
  key_vault_id = var.key_vault_id
}

data "azurerm_key_vault_secret" "ca_root_cert" {
  name         = "${var.ingress_id}-ca-root-cert"
  key_vault_id = var.key_vault_id
}

# Generate the Private Key
resource "tls_private_key" "csr_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create the Certificate Signing Request (CSR)
resource "tls_cert_request" "backend_leaf" {
  private_key_pem = tls_private_key.csr_private_key.private_key_pem

  subject {
    common_name = var.common_name
  }

  dns_names    = var.dns_names
  ip_addresses = var.ip_addresses
}

# Use the Root CA to Sign the CSR (Generating the Leaf Cert)
resource "tls_locally_signed_cert" "backend_leaf" {
  cert_request_pem   = tls_cert_request.backend_leaf.cert_request_pem
  ca_private_key_pem = data.azurerm_key_vault_secret.ca_private_key.value
  ca_cert_pem        = data.azurerm_key_vault_secret.ca_root_cert.value

  validity_period_hours = var.validity_period_hours

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Write the Private Key
resource "local_sensitive_file" "private_key" {
  content  = tls_private_key.csr_private_key.private_key_pem
  filename = "${path.module}/${var.common_name}.key"
}

# Write the Leaf Cert and the full chain (Leaf + Root) to local file 
resource "local_file" "full_chain" {
  # Order is critical: Leaf first, then any Intermediates, then the Root.
  # Use a heredoc (<<-EOT) or join() to combine them.
  content  = <<-EOT
${tls_locally_signed_cert.backend_leaf.cert_pem}
${data.azurerm_key_vault_secret.ca_root_cert.value}
EOT
  filename = "${path.module}/${var.common_name}.crt"
}

# Generate the PFX file using OpenSSL via a local-exec provisioner
resource "terraform_data" "generate_pfx" {
  triggers_replace = {
    cert_pem            = tls_locally_signed_cert.backend_leaf.cert_pem
    root_cert_pem       = data.azurerm_key_vault_secret.ca_root_cert.value
    csr_private_key_sha = sha256(tls_private_key.csr_private_key.private_key_pem)
    password_sha        = sha256(var.pfx_password)
  }

  provisioner "local-exec" {
    environment = {
      PFX_PASSWORD = var.pfx_password
    }

    command = <<EOT
      openssl pkcs12 -export -out ${path.module}/${var.common_name}.pfx \
        -inkey ${local_sensitive_file.private_key.filename} \
        -in ${local_file.full_chain.filename} \
        -passout env:PFX_PASSWORD \
        -name ${var.common_name}
    EOT
  }

  # This ensures the command only runs after the files are written
  depends_on = [
    local_file.full_chain,
    local_sensitive_file.private_key
  ]
}

# Upload the PFX cert to Azure Blob Storage
resource "azurerm_storage_blob" "pfx_cert" {
  name                   = "software/certificates/${var.deployment_id}/${var.common_name}.pfx"
  storage_account_name   = var.storage_account_name
  storage_container_name = var.storage_container_name
  source                 = pathexpand("${path.module}/${var.common_name}.pfx")
  type                   = "Block"

  depends_on = [
    terraform_data.generate_pfx
  ]
}
