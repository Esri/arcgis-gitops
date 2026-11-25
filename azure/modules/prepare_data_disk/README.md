# Terraform Module for Azure Windows Data Disk Preparation

Prepares the existing D: data disk on primary/standby deployment VMs in the
specified roles. The `prepare_data_disk` module validates and expands the
existing partition, verifies image-time Users permissions, and reconciles the
original local service-account SID.

The deployment script:

1. Runs the module's standalone [prepare_data_disk.ps1](scripts/prepare_data_disk.ps1)
   through the existing Azure Run Command workflow. It does not invoke or require
   a baked initializer.
2. Validates the existing LUN 0 disk and NTFS partition before safe D: assignment.
   It checks disk identity, mapping, online/writable state and write/read access.
   It cannot initialize disks, create partitions, or format volumes. It
   expands the existing partition to the largest supported MiB-aligned size,
   verifies the result, and refuses to initialize or format a missing/blank disk.
3. Verifies the inheritable Users Full Control grant on `D:\data` and rejects common
   Users/Everyone/Authenticated Users Deny rules. It does not grant permissions.
4. Matches the OS and data disk identity records, then replaces only the recorded
   local SID in owners and DACL entries across the verified volume. It binds the
   disk to the VM's unique identity. Nonlocal accounts are verified but unchanged.
   The application apply checks the completion marker and configured account
   before starting bootstrap.

## Requirements

On the Terraform execution machine:

* Python 3.9 or later with the repository's Azure SDK for Python dependencies.
* The repository's `azure/scripts` directory on `PYTHONPATH`.
* Azure credentials authorized to read the enterprise Key Vault and execute the
  existing `az_run_shell_script` VM Run Command workflow. No new role assignments
  are created by this module.

Target VMs must have the persistent LUN 0 NTFS disk with `D:\data` and
image-time Users permissions, plus the Azure VM agent. Run Command executes
with the guest privileges required to prepare the disk and read the `D:\data` ACL.

Disk initialization and recursive ACL grants belong to the image's separate
[initial](../../arcgis-enterprise-base-windows/image/scripts/initialize_data_disk.ps1)
and [final](../../arcgis-enterprise-base-windows/image/scripts/prepare_image_data_disk.ps1)
preparation scripts. Run the infrastructure apply before application configuration.
The recorded local account must already exist when disk preparation runs.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| null | n/a |

## Modules

None.

## Resources

| Name | Type |
|------|------|
| null_resource.prepare | resource |
| azurerm_key_vault.enterprise_vault | data source |
| azurerm_resources.enterprise_vault | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| vm_resource_id | Exact Azure VM resource ID | `string` | n/a | yes |
| expected_account | Configured application account for read-only verification mode | `string` | `null` | no |

## Outputs

None.

