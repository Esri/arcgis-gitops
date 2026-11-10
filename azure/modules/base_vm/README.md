# Terraform Module base_vm

Creates a Linux or Windows VM in an existing resource group and VM scale set
using AzAPI. The VM uses an existing NIC and user-assigned managed identity.
Its OS disk and data disk at LUN 0 are restored from an Azure Compute Gallery
image version. The module does not create networking, identities, or gallery
images.

## Requirements

* Terraform 1.11.0 or later
* Azure credentials authorized to read the gallery image version and create the VM
* Existing resource group, VM scale set, NIC, and user-assigned managed identity
* Gallery image version containing data LUN 0
* A password for Windows or password-authenticated Linux VMs, or a public SSH key for Linux VMs

## Providers

| Name | Version |
|------|---------|
| azapi | ~> 2.6 |

## Resources

| Name | Type |
|------|------|
| azapi_resource.image | data source |
| azapi_resource.vm | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| settings | VM configuration described below | `object` | n/a | yes |
| admin_password | Sensitive VM administrator password; omit for Linux SSH-key authentication | `string` | `null` | no |

The `settings` object has these fields:

| Field | Description | Type | Required |
|-------|-------------|------|:--------:|
| name | VM resource name and guest computer name | `string` | yes |
| resource_group_id | Resource ID of the existing resource group | `string` | yes |
| location | Azure region | `string` | yes |
| size | Azure VM size | `string` | yes |
| image_id | Azure Compute Gallery image version resource ID | `string` | yes |
| nic_id | Existing network interface resource ID | `string` | yes |
| identity_id | Existing user-assigned managed identity resource ID | `string` | yes |
| scale_set_id | Existing VM scale set resource ID | `string` | yes |
| os_disk_size | OS disk capacity in GiB, at least the image OS disk size | `number` | yes |
| data_disk_size | Data disk capacity in GiB, at least the image data LUN 0 size | `number` | yes |
| windows | Whether the VM runs Windows rather than Linux | `bool` | yes |
| admin_username | Guest administrator account name | `string` | yes |
| public_key | Linux public SSH key; defaults to null and disables password authentication when provided | `string` | no |
| tags | Tags applied to the VM resource | `map(string)` | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | VM resource ID |

