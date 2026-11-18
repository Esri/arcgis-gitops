# Terraform Module for Azure Windows OS Partition Expansion

Expands the running Windows C: NTFS partition into available capacity on its
existing Azure OS disk. Provisioning a 256 GiB managed disk does not guarantee
that a 128 GiB image partition will automatically expand.

The base Windows infrastructure calls this module for primary, standby (when
enabled), and its dedicated file-server VM. OS preparation runs after VM creation
and the file-server data-disk extension, before primary/standby D: preparation.
Other templates and externally shared file servers are not changed.

## Behavior and Safety

The standalone [script](scripts/prepare_os_disk.ps1) runs through the existing
`az_run_shell_script` Azure Run Command workflow on every Terraform apply.
It refreshes storage inventory, requires C: to be the running OS volume, and
verifies local NTFS mapping, stable boot-disk identity, healthy online/writable
state, and guest disk capacity against `os_disk_size`.

The script queries the supported C: partition size and expands only that
partition to its maximum MiB-aligned extent when at least 1 MiB of growth is
available. It verifies both partition and NTFS volume sizes afterward, allowing
up to 1 MiB of normal disk reporting, alignment, and filesystem overhead.
Repeated execution on an expanded disk is a verified no-op.

Allocated EFI, MSR, and recovery partitions are not treated as missing capacity.
If at least 1 MiB of unused capacity remains beyond C:'s supported growth extent,
the script **fails before resizing**, even if partial growth is possible. Output
includes the disk capacity, configured capacity, C: size, supported maximum,
and ordered partition numbers/types/offsets/sizes. An intervening recovery
partition commonly causes this condition.

Review these diagnostics through the approved deployment logs. Recovery-layout
remediation requires a separate reviewed change and risk approval. The script
never moves/deletes other partitions, formats/initializes disks, disables WinRE,
changes boot settings, reboots, grants ACLs, or controls services.

Review the OS-disk blast radius and maintenance impact and retain a verified
OS-disk/VM backup before applying. A failure on one VM does not undo successful
expansion on another. Removing this module or reverting source does not shrink
partitions or undo a completed expansion. Use approved backup restoration if
OS-disk recovery is required; do not shrink partitions as rollback.

## Requirements

- Terraform and the Azure providers used by the calling infrastructure; the base
  Windows template requires Terraform 1.11 or later.
- Python 3.9 or later and the repository's Azure SDK dependencies, with
  `azure/scripts` on `PYTHONPATH`.
- Existing Azure authorization to discover tagged deployment VMs, read the
  enterprise Key Vault, and execute VM Run Commands. No new roles are assigned.
- Target VMs with the Azure VM agent and privileges for Windows storage refresh
  and C: expansion. The actual OS disk must already be provisioned to at least
  `os_disk_size`; this module does not enlarge the Azure managed disk itself.
- A compatible partition layout and healthy local C: NTFS volume on the boot
  disk. No baked helper, image rebuild, service downtime automation, or reboot
  is introduced by this module.

## Providers

| Name | Version |
|------|---------|
| azurerm | Inherited from caller; no child constraint |
| null | Inherited from caller; no child constraint |

## Modules

None.

## Resources

| Name | Type |
|------|------|
| null_resource.prepare | resource |
| azurerm_resources.enterprise_vault | data source |
| azurerm_key_vault.enterprise_vault | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| machine_roles | Deployment Windows VM roles whose C: partitions will be prepared (`primary`, `standby`, `fileserver`) | `list(string)` | n/a | yes |
| os_disk_size | Expected minimum guest OS disk capacity in GiB, matching the provisioned managed disk; integer 256-4095 | `number` | n/a | yes |

## Outputs

None.

## Key Vault Configuration

The module locates the enterprise vault in
`${enterprise_id}-infrastructure-core` using the existing enterprise-vault tags.
The existing Run Command helper reads its standard enterprise authentication
configuration, including `vm-identity-client-id`. Credentials remain in approved
Azure authentication/Key Vault configuration; none are embedded in scripts.
This module writes no Key Vault secrets.

