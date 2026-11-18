# Terraform module ec2_fileserver

OS disk inputs `os_disk_size`, `os_disk_type`, `os_disk_iops`, and
`os_disk_throughput` default to 256 GiB, gp3, 3,000 IOPS, and 125 MiB/s.
Base-enterprise deployments pass their OS settings through to this module.
Data-volume properties remain independent.

This reusable module creates or references a dedicated Windows EC2 file-server VM.

Owned file servers require an AMI with exactly one `/dev/sdf` EBS snapshot
containing the initialized GPT/NTFS D: disk. The launch mapping restores that
snapshot; `data_volume_size` must be at least its image capacity. Missing
snapshots and shrink requests fail instead of provisioning blank disks.
For owned file servers, the module invokes
[prepare_windows_disks](../prepare_windows_disks/README.md) to verify and expand
C: then the restored D: partition on every apply. It waits for successful SSM
completion before exposing dependent outputs and publishing metadata.
Preparation verifies guest-visible EBS capacity and partition/NTFS sizes and
requires the image-time Users Full Control grant on D:. It does not initialize,
format, repair ACLs, start services, or change WinRE/recovery partitions.
Partition growth cannot be undone by reducing `data_volume_size`.
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

## Requirements

Terraform >= 1.10.0, AWS credentials, Python with Boto3, and `aws/scripts` on
`PYTHONPATH`. Owned instances must be SSM-managed and use a rebuilt file-server
AMI with the image-time Users grant. The existing SSM role must permit enterprise
log-bucket output. Referenced instances are not resized or otherwise prepared.
Review maintenance impact, the image security exception, and matched OS/data
backups before rollout. Blocked layouts require separately approved remediation.

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.10 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| prepare_disks | ../prepare_windows_disks | n/a |

## Resources

| Name | Type |
|------|------|
| aws_security_group.fileserver | resource |
| aws_vpc_security_group_ingress_rule.smb | resource |
| aws_vpc_security_group_ingress_rule.rpc | resource |
| aws_network_interface.fileserver | resource |
| aws_instance.fileserver | resource |
| aws_route53_record.fileserver | resource |
| aws_ssm_parameter.security_group_id | resource |
| aws_ssm_parameter.private_dns | resource |
| aws_ssm_parameter.instance_id | resource |
| aws_ssm_parameter.instance_arn | resource |
| aws_ssm_parameter.ami | data source |
| aws_ami.fileserver | data source |
| aws_vpc.deployment | data source |
| aws_ssm_parameter.shared_security_group_id | data source |
| aws_ssm_parameter.shared_private_dns | data source |
| aws_ssm_parameter.shared_instance_id | data source |
| aws_ssm_parameter.shared_instance_arn | data source |

## SSM Parameters

An owned file server reads
`/arcgis/${enterprise_id}/images/${deployment_id}/fileserver` for its AMI and,
through the preparation module, `/arcgis/${enterprise_id}/s3/logs` for output.
It writes the following metadata. Reference mode instead reads the same paths
under `${fileserver_deployment_id}` and does not write owner metadata:

| Path | Description |
| --- | --- |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/instance-arn` | EC2 instance ARN |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/instance-id` | EC2 instance ID |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/private-dns` | Private DNS name |
| `/arcgis/${enterprise_id}/${deployment_id}/fileserver/security-group-id` | Dedicated security group ID |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| deployment_id | ArcGIS deployment ID | `string` | n/a | yes |
| fileserver_deployment_id | Existing owner; otherwise creates a dedicated VM | `string` | `null` | no |
| instance_type | File-server EC2 instance type | `string` | n/a | yes |
| key_name | EC2 key pair name | `string` | n/a | yes |
| iam_instance_profile | Existing IAM instance profile name | `string` | n/a | yes |
| subnet_id | Primary deployment subnet | `string` | n/a | yes |
| vpc_id | Enterprise VPC | `string` | n/a | yes |
| referenced_security_group_id | Consumer deployment security group | `string` | n/a | yes |
| hosted_zone_id | Route 53 private hosted zone ID | `string` | n/a | yes |
| arcgis_template_id | ArcGIS template tag value | `string` | n/a | yes |
| arcgis_version | ArcGIS version tag value | `string` | `null` | no |
| data_volume_size | Data EBS capacity in GiB | `number` | n/a | yes |
| data_volume_type | Data EBS type: gp3, io1, io2, sc1, or st1 | `string` | n/a | yes |
| data_volume_iops | Provisioned data EBS IOPS where applicable | `number` | n/a | yes |
| data_volume_throughput | Provisioned gp3 throughput in MiB/s | `number` | n/a | yes |
| os_disk_size | OS EBS capacity in GiB | `number` | `256` | no |
| os_disk_type | OS EBS type | `string` | `"gp3"` | no |
| os_disk_iops | OS EBS IOPS | `number` | `3000` | no |
| os_disk_throughput | OS EBS throughput in MiB/s | `number` | `125` | no |

## Outputs

| Name | Description |
| --- | --- |
| `instance_arn` | Created or referenced instance ARN |
| `instance_id` | Created or referenced instance ID |
| `private_dns` | Created or referenced private DNS name |
| `security_group_id` | Created or referenced security group ID |
