# Terraform Module prepare_windows_disks

Synchronously verifies and expands C: and D: on one owned Windows EC2 instance
on every Terraform apply. C: is prepared first; a failure prevents D:
preparation and fails the apply. An unchanged, fully expanded disk is a no-op.

The module waits for SSM readiness, then sends the standalone scripts to the
exact instance ID using `AWS-RunPowerShellScript`. It does not depend on EC2 user
data, image-baked scripts, startup tasks, or guest AWS credentials. Actual data
EBS volume IDs identify disks by normalized guest serial, not disk number.

## Requirements

- Terraform >= 1.10.0, Python with Boto3, and `aws/scripts` on `PYTHONPATH`.
- Existing AWS credentials permitted to discover the deployment/SSM instances,
  read the enterprise log-bucket parameter, and manage SSM associations.
- SSM-managed Windows with Storage cmdlets, healthy NTFS C: and a restored
  GPT/NTFS data disk. D: must have the image-time built-in Users Full Control
  root grant. Rebuild legacy AMIs; this module never repairs ACLs.
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
| terraform_data.readiness | resource |
| aws_ssm_association.prepare | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| deployment_id | ArcGIS deployment ID | `string` | n/a | yes |
| machine_role | Owned primary, standby, or fileserver role | `string` | n/a | yes |
| instance_id | Exact EC2 instance ID | `string` | n/a | yes |
| data_volume_id | Actual EBS volume restored from AMI /dev/sdf | `string` | n/a | yes |
| os_disk_size | Expected OS EBS capacity in GiB, integer 256-16384 | `number` | n/a | yes |
| data_disk_size | Expected data EBS capacity in GiB, integer 1-65536 | `number` | n/a | yes |

Parent modules retain their EBS-type-specific size restrictions. Guest
partition-table and NTFS limits still apply; large MBR OS disks are rejected,
not converted.

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID after successful C: and D: preparation |

## SSM Parameters and Logs

Reads `/arcgis/${enterprise_id}/s3/logs`; writes no SSM parameters.
Command output is written to that bucket under
`${deployment_id}/disk-preparation/${machine_role}`. Association execution
status and command errors are available through Systems Manager.

The bounded readiness helper selects the role by deployment tags. The
association itself targets `instance_id`, and Terraform waits for its result;
an empty tag lookup alone cannot make preparation succeed.

## Safety and Recovery

EBS allocation does not guarantee Windows partition or NTFS growth. Both scripts
refresh/verify guest capacity and check identities and final sizes. C: fails
before resizing if recovery/other partitions block meaningful unused space.
Neither script formats/initializes deployment disks, shrinks, alters WinRE,
reboots, mutates ACLs, or controls services.

D: may safely online/unlock its identified EBS disk and reassign a positively
identified non-OS/optical D: occupant to a free T:-Z: letter. Ambiguous, redirected,
or system mappings fail. Verify this blast radius in the deployment PR.

Review the plan, maintenance impact, and verified backups before applying.
There is deliberately an every-apply SSM operation even when no growth is
necessary. Reverting source or lowering sizes cannot undo partition growth;
restore matched OS/data backups through approved recovery when needed.

## Validation

Run the mocked Pester suite in `tests/disk_lifecycle.Tests.ps1` in a fresh Windows
PowerShell process and `terraform test` for `tests/preparation.tftest.hcl`.
Mocks do not prove real EBS enumeration, SSM registration, effective access, or
application health; disposable-AWS acceptance is required before rollout.
