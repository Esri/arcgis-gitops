# Terraform Module repair_data_disk_permissions

Grants the logon account of the Portal for ArcGIS Windows service Full Control
on `D:\arcgisportal`, `D:\arcgisdatastore`, and all descendants on deployment VMs
in the specified roles. Uses the permissions repair logic from the
[AWS permissions repair script](../../../aws/arcgis-enterprise-base-windows/infrastructure/scripts/repair_data_disk_permissions.ps1).

The script resolves the deployed account's SID, validates that `D:` is an online,
writable, non-OS NTFS data disk.
It rejects reparse points, preserves existing owners, other ACL entries, and
inheritance protection, and verifies each Full Control grant. Like the AWS
script, it then restarts both services using `Restart-Service` and waits up to
five minutes per service for the Windows service status to reach `Running`.
Service startup types are never changed; disabled services fail to restart.

## Operational Safety

The repair runs on every Terraform apply, after the caller's VM dependencies
are ready. Both services are restarted only after a successful repair; they are
not stopped beforehand. Applying to an already configured deployment briefly
interrupts these services; use an approved maintenance window. A repair failure
does not restart services. Restart errors or timeouts fail the operation;
check both services before retrying. A `Running` service status is not an
application health check.

Before applying to an existing deployment, retain a recoverable data-disk backup
or ACL export. Removing this module does not undo permissions. To roll back,
restore the prior ACLs or data disk through the approved recovery procedure, then
run the application workflow to configure and start the services. This module
does not change loopback aliases or remove existing BackConnectionHostNames.

## Requirements

On the Terraform execution machine:

* Python 3.9 or later with the repository's Azure SDK for Python dependencies.
* The repository's `azure/scripts` directory on `PYTHONPATH`.
* Azure credentials authorized to read the enterprise Key Vault and execute the
  existing `az_run_shell_script` VM Run Command workflow. No new role assignments
  are created by this module.

Target VMs must have the Azure VM agent, Portal for ArcGIS and ArcGIS Data Store
services, and both existing data directories on `D:`. Run Command executes the
script with the guest privileges required to restart services and update ACLs.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| null_resource.repair | resource |
| azurerm_key_vault.enterprise_vault | data source |
| azurerm_resources.enterprise_vault | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |