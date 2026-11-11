# Terraform module ec2_fileserver

OS disk inputs `os_disk_size`, `os_disk_type`, `os_disk_iops`, and
`os_disk_throughput` default to 256 GiB, gp3, 3,000 IOPS, and 125 MiB/s.
Base-enterprise deployments pass their OS settings through to this module.
Data-volume properties remain independent. See [disk layout and recovery](../../../config/scripts/README.md).

This reusable module creates or references a dedicated Windows EC2 file-server VM.

Owned file servers require an AMI with exactly one `/dev/sdf` EBS snapshot
containing the initialized GPT/NTFS D: disk. The launch mapping restores that
snapshot; `data_volume_size` must be at least its image capacity. Missing
snapshots and shrink requests fail instead of provisioning blank disks.
For owned file servers, the module runs an SSM association to verify the restored
data disk and grow its partition, and waits for success before exposing dependent
outputs. Partition growth cannot be undone by reducing `data_volume_size`.
Verify application-level file-server service readiness separately through an
approved operational procedure before application configuration.

Rebuild legacy file-server images before using this contract for new deployments.
There is no automatic migration. Backup recovery continues to use the matched
OS/data snapshots from the file-server recovery AMI. Legacy restores lacking the
mapping require their prior compatible code and a separately reviewed procedure.
Keep old environments and backups until acceptance; reverting source cannot
reverse filesystem growth or resource replacement.

AWS base ArcGIS Enterprise Windows roots always leave `fileserver_deployment_id` null and therefore create and own one dedicated file server. They do not expose reference mode.

For a future non-base Windows consumer in the same `enterprise_id` and VPC, setting `fileserver_deployment_id` reads exactly one base owner's metadata and adds SMB/RPC ingress for the consumer security group without creating a VM, disk, DNS record, metadata, monitoring assignment, or backup assignment.

The owning deployment remains responsible for backup and lifecycle management.

## SSM Parameters

The module reads or writes these paths for the owning deployment:

| Path | Description |
| --- | --- |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/instance-arn` | EC2 instance ARN |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/instance-id` | EC2 instance ID |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/private-dns` | Private DNS name |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/security-group-id` | Dedicated security group ID |

## Key Inputs

| Name | Description | Default |
| --- | --- | --- |
| `deployment_id` | Current deployment ID | Required |
| `enterprise_id` | ArcGIS Enterprise ID | Required |
| `fileserver_deployment_id` | Existing owning deployment ID | `null` |
| `referenced_security_group_id` | Consumer deployment security group | Required |
| `subnet_id` | Primary deployment subnet | Required |
| `vpc_id` | Enterprise VPC | Required |

## Outputs

| Name | Description |
| --- | --- |
| `instance_arn` | Created or referenced instance ARN |
| `instance_id` | Created or referenced instance ID |
| `private_dns` | Created or referenced private DNS name |
| `security_group_id` | Created or referenced security group ID |
