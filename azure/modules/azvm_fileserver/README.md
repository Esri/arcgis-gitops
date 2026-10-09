# Terraform module azvm_fileserver

This reusable module creates or references a dedicated Windows Azure file-server VM. Azure ArcGIS Enterprise base deployments always call it without `fileserver_deployment_id` and therefore always own their file server.

When `fileserver_deployment_id` is null, the module creates the VM, NIC, fixed OS disk, configurable data disk, private DNS record, and Key Vault metadata. The VM inherits the existing NSG attached to `subnet_id`, just like the primary and standby VMs in that subnet. The module does not create an NSG or a NIC-level NSG association, and rejects a subnet without an NSG. The nullable input is retained only for future non-base Windows consumers: when set, the module reads the owner's metadata from the same enterprise Key Vault without creating another VM.

The owning base deployment remains responsible for backup and lifecycle management. A future referenced deployment must use the same `enterprise_id` and enterprise Key Vault and must be in the enterprise VNet covered by the owner's subnet NSG rules.

## Network Security and Existing Deployments

The `security_group_id` output and `${deployment_id}-fileserver-security-group-id`
secret retain their names, but now identify the inherited subnet NSG for newly
created file servers. Referenced deployments continue to read the owner's stored
NSG ID.

For an existing deployment, review an infrastructure plan before applying:
Terraform should remove only the dedicated file-server NSG and its NIC
association, update the NSG metadata, and preserve the VM, NIC, disks, and backups.
The subnet NSG remains managed by the enterprise core infrastructure (or the
owner of a custom subnet). Review its effective rules for required file-server
access, including SMB, before approving the change; this module does not modify
those rules. Use approved infrastructure automation to apply or roll back the
change. Rolling back to the previous module recreates the dedicated NSG and NIC
association.

## Data Disk Initialization

The owning deployment attaches its managed data disk at LUN 0. The
`initialize-fileserver-data-disk` Custom Script Extension runs
[initialize_data_disk.ps1](initialize_data_disk.ps1) using Windows PowerShell.
Terraform embeds the script as a compressed payload, keeping the command below
Windows `cmd.exe`'s 8191-character limit without downloading another file.

Initialization selects exactly one non-OS disk at LUN 0 and inventories
partitions, volumes, logical disks, optical drives (including empty drives),
PowerShell drives, and native DOS-device mappings. A recognized non-OS D:
partition or optical drive is relocated to an unused letter from T: through Z:.
OS/system devices, redirected or ambiguous mappings, and unknown occupants are
rejected. The displaced device is never formatted.

An offline target disk is brought online to inspect its existing partitions.
If a later safety check fails, it may remain online, but no partition is created
or formatted before the disk layout and D: occupant have been checked.

Only a new RAW disk or a recognized RAW/Unknown volume is formatted. Existing
NTFS data is preserved on reruns; unsupported filesystems and missing volumes
fail explicitly. Before success, the script rechecks the disk identity, D:
partition, NTFS filesystem, native mount mapping, and online/writable state,
then writes, reads, and deletes a uniquely named probe. Any error returns exit
code 1 with its original message and script stack trace.

### Recovery from an Earlier False Success

Do not start application configuration until the file-server extension reports
`Verified writable NTFS D: on LUN 0 disk ...`. Inspect extension stdout/stderr and
guest disk/volume inventories if initialization fails. A workflow's earlier
success alone does not prove D: is usable.

Review an infrastructure Terraform plan using the updated module before applying
it. Changed extension settings should rerun initialization. If an unchanged
extension must be rerun, use the owning infrastructure state and explicitly
replace only
`module.azvm_fileserver.azurerm_virtual_machine_extension.initialize_data_disk[0]`
through an approved Terraform operation. Do not recreate the VM or managed data
disk, format an unknown volume, or manually change OS drive letters. Verify that
the plan preserves the VM, managed disk, and backups. If guest Run Command is
already in progress, wait for it to finish rather than issuing overlapping
diagnostic requests.

After successful initialization, rerun application configuration, deployment
tests, and backup validation. If Cinc still reports `ReportEvent`, investigate
its event-logging failure independently; the disk correction does not prove
that error is resolved.

## Key Vault Secrets

The module reads or writes these secrets for the owning deployment:

| Name | Description |
| --- | --- |
| `${deployment_id}-fileserver-private-dns` | Private DNS name |
| `${deployment_id}-fileserver-security-group-id` | Inherited subnet NSG ID |
| `${deployment_id}-fileserver-vm-id` | Virtual machine ID |

## Key Inputs

| Name | Description | Default |
| --- | --- | --- |
| `deployment_id` | Current deployment ID | Required |
| `enterprise_id` | ArcGIS Enterprise ID | Required |
| `fileserver_deployment_id` | Existing owning deployment ID | `null` |
| `resource_group_name` | Current deployment resource group | Required |
| `subnet_id` | Subnet shared with primary and standby VMs, with an existing NSG | Required |
| `vault_id` | Enterprise Key Vault ID | Required |

## Outputs

| Name | Description |
| --- | --- |
| `vm_id` | Created or referenced VM ID |
| `private_dns` | Created or referenced private DNS name |
| `security_group_id` | Inherited subnet or referenced owner's NSG ID |
