# Terraform Module for Azure Windows Data Disk Preparation

Prepares the existing D: data disk on primary/standby deployment VMs in the
specified roles. The `prepare_data_disk` module validates and expands the
existing partition and verifies image-time Users permissions. It does not
repair ACLs or control services.

The deployment script:

1. Runs the module's standalone [prepare_data_disk.ps1](scripts/prepare_data_disk.ps1)
   through the existing Azure Run Command workflow. It does not invoke or require
   a baked initializer.
2. Validates the existing LUN 0 disk and NTFS partition before safe D: assignment.
   It checks disk identity, mapping, online/writable state and write/read access.
   It cannot initialize disks, create partitions, or format volumes. It
   expands the existing partition to the largest supported MiB-aligned size,
   verifies the result, and refuses to initialize or format a missing/blank disk.
3. Verifies the inheritable Users Full Control root grant and rejects common
   Users/Everyone/Authenticated Users Deny rules. It does not grant permissions.

## Requirements

On the Terraform execution machine:

* Python 3.9 or later with the repository's Azure SDK for Python dependencies.
* The repository's `azure/scripts` directory on `PYTHONPATH`.
* Azure credentials authorized to read the enterprise Key Vault and execute the
  existing `az_run_shell_script` VM Run Command workflow. No new role assignments
  are created by this module.

Target VMs must have the persistent LUN 0 NTFS disk with image-time Users
permissions and the Azure VM agent. Run Command executes
with the guest privileges required to prepare the disk and read its root ACL.

Disk initialization and recursive ACL grants belong to the image's separate
[initial](../../arcgis-enterprise-base-windows/image/scripts/initialize_data_disk.ps1)
and [final](../../arcgis-enterprise-base-windows/image/scripts/prepare_image_data_disk.ps1)
preparation scripts. This module does not change service startup or grant ACLs.

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

## Outputs

None.

## Validation

Run the shared stage-boundary tests from this module directory:

```powershell
powershell.exe -NoProfile -Command "Invoke-Pester -Script ..\..\arcgis-enterprise-base-windows\image\scripts\tests\data_disk_scripts.Tests.ps1"
```

Tests mock all disk, file, ACL, and service operations. Before rollout, use an
approved disposable Azure VM to verify post-Sysprep Users/service-account access,
LUN 0/D: mapping, larger-disk expansion, application health, and reboot behavior.
Disk expansion is not automatically reversible; restore a verified backup rather
than shrink the partition. No production build or apply is part of local tests.
