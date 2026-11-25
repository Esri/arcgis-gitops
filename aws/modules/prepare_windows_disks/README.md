# Terraform Module prepare_windows_disks

Synchronously verifies and expands C: and D: on all eligible Windows EC2
instances matching the enterprise, deployment, and machine-role tags on every
Terraform apply. No instance or volume IDs are required from the caller.

The runner waits for every matching instance to become SSM Online and verifies
its attached `/dev/sdf` EBS volume before sending `AWS-RunPowerShellScript` by
tag. The guest confirms its IMDSv2 instance ID and expected EBS disk serial
before preparing C:, then D:. All validated targets must succeed. The module
does not depend on EC2 user data, startup tasks, or guest AWS credentials.

## Requirements

- Terraform >= 1.10.0, Python with Boto3, and `aws/scripts` on `PYTHONPATH`.
- Existing AWS credentials for EC2 instance and volume discovery, SSM
  readiness, `ssm:SendCommand` and `ssm:ListCommandInvocations`, and access to
  the log-bucket parameter and S3 log prefix. Removing a legacy association
  also requires the existing association management permissions.
- SSM-managed Windows with Storage cmdlets, healthy NTFS C: and a restored
  GPT/NTFS data disk. `D:\data` must exist and have the image-time built-in
  Users Full Control grant. Rebuild legacy AMIs or use an approved migration.
  Run the infrastructure apply before application configuration.
- The instance's existing SSM role must permit command execution and writing
  output to the enterprise log bucket. No role/policy changes are made here.

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.10 |
| terraform | built in |

## Modules

None.

## Resources

| Name | Type |
|------|------|
| aws_region.current | data source |
| aws_ssm_parameter.logs | data source |
| terraform_data.prepare_with_logs | resource; tag-targeted Run Command |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| deployment_id | ArcGIS deployment ID | `string` | n/a | yes |
| machine_role | Exact `ArcGISMachineRole` tag; starts with a letter or digit and permits letters, digits, dots, underscores, and hyphens | `string` | n/a | yes |
| image_role | Expected image identity kind (`application` or `fileserver`), independent of the machine-role tag | `string` | `"application"` | no |
| os_disk_size | Expected OS EBS capacity in GiB, integer 256-16384 | `number` | n/a | yes |
| data_disk_size | Expected data EBS capacity in GiB, integer 1-65536 | `number` | n/a | yes |
| expected_snapshot_id | Expected AMI data snapshot ID for the attached volume | `string` | `null` | no |
| allow_data_disk_rebind | Allow an approved recovery to replace an application data disk binding | `bool` | `false` | no |
| log_to_apply | Replay S3 command output during apply | `bool` | `false` | no |
| fileserver_private_dns | Private DNS alias for observable file-server registry setup | `string` | `null` | no |
| fileserver_registry_script | Module-local registry setup script supplied by the file-server module | `string` | `""` | no |
| expected_account | Configured application account for read-only verification mode | `string` | `null` | no |

Parent modules retain their EBS-type-specific size restrictions. Guest
partition-table and NTFS limits still apply; large MBR OS disks are rejected,
not converted.

## Outputs

None. The former singular `instance_id` output was removed.

## SSM Parameters and Logs

Reads `/arcgis/${enterprise_id}/s3/logs`; writes no SSM parameters.
Command output is written to that bucket under
`${deployment_id}/disk-preparation/${machine_role}/<command-id>/<instance-id>/`.
Systems Manager provides status and exit codes. Log contents are replayed only
from S3. An empty tag lookup fails after the readiness timeout.

## Upgrade from State Manager

If a previous deployment still has an `aws_ssm_association.prepare` in state,
remove it in a separate reviewed maintenance step before the first full apply
of this version. From the upgraded configuration, target the legacy association
address in a saved Terraform plan and verify that the plan only removes the
association and any reviewed legacy preparation state. After that step, confirm
any previously started SSM executions are terminal. Then review the full plan:
the disk-runner resource is replaced on each apply; EC2 instances and EBS
volumes must not be replaced on account of this module upgrade.

## Safety and Recovery

The SID repair helpers are bundled from this module's `scripts/` directory.
Keep the matching Azure module copies in sync when changing repair logic, and
update both Packer copies when changing `image_identity.ps1`.

Infrastructure validates the attached volume's source snapshot and matches the
protected `%SystemRoot%\ArcGIS-ImageIdentity\service-account.json` to its copy on the
data disk, including the GPT partition ID. The first repair binds the data volume
to the EC2 instance and the source/target SIDs. Callers that set `expected_account`
verify preparation and the configured account without resizing or repairing disks.
The recorded local account must already exist on the VM. Nonlocal SIDs remain
unchanged if verified, and the standard file-server image records no account.
For standard file-server images, an existing deployment binding is not reused
for SID changes and does not block a new VM or restored data attachment.

While the volume is offline to applications and share clients, the guest's
Systems Manager account uses its Windows backup/restore privileges to scan the
verified NTFS volume, including its root. It changes only the exact recorded SID
in owners and DACL entries, including inherited copies without changing ACE flags
or propagating writes. It does not recurse through reparse points or grant Users
Full Control on `D:\`. Unsupported or access-denied objects stop the run.

Before review and rollout, take an approved data-volume snapshot with application
writes quiesced. For a partial repair, preserve the logs, the original volume and
the protected `%SystemRoot%\ArcGIS-ImageIdentity\descriptor-backup.json`. After
confirming the same VM, disk, and account and correcting the reported failure,
rerun infrastructure preparation. A descriptor that no longer matches either
journal value blocks retry. The error identifies which descriptor fields differ
from each saved state without printing the ACL. Keep the journal intact for
diagnosis. For DACL writes, verification allows NTFS to clear the DACL
defaulted and auto-inherit request flags. The replacement can also omit later
byte-identical Allow entries, provided every other entry stays in order.
The saved original does not allow this omission. For rollback, use the pre-change
disk snapshot or the reconciliation helper's `-Restore` mode in a reviewed recovery workflow on
the original VM and volume. Do not delete the binding or forge metadata to resume.
A restored or cloned volume needs separate review; a matching marker alone does
not authorize repair. Rebuild missing-metadata images rather than choosing an
orphaned SID by hand.

EBS allocation does not guarantee Windows partition or NTFS growth. Both scripts
refresh/verify guest capacity and check identities and final sizes. C: fails
before resizing if recovery/other partitions block meaningful unused space.
Neither script formats/initializes deployment disks, shrinks, alters WinRE,
reboots, or controls services. Only the data script changes ACLs, through the
SID reconciliation described above.

D: may safely online/unlock its identified EBS disk and reassign a positively
identified non-OS/optical D: occupant to a free T:-Z: letter. Ambiguous, redirected,
or system mappings fail. Verify this blast radius in the deployment PR.

Review the plan, maintenance impact, and verified backups before applying.
There is deliberately an every-apply SSM operation even when no growth is
necessary. Reverting source or lowering sizes cannot undo partition growth;
restore matched OS/data backups through approved recovery when needed.

## Validation

Validate the calling Terraform configuration and review a plan against the
target environment before rollout. On a disposable AWS deployment, verify
single- and multi-instance roles, SSM registration, EBS enumeration, and S3
output. Local mocks cannot establish those AWS behaviors or application health.
