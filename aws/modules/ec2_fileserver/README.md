# Terraform module ec2_fileserver

This reusable module creates or references a dedicated Windows EC2 file-server VM.

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
| `data_disk_association_id` | Owned data-disk initialization association ID, or `null` in reference mode |
| `instance_arn` | Created or referenced instance ARN |
| `instance_id` | Created or referenced instance ID |
| `private_dns` | Created or referenced private DNS name |
| `security_group_id` | Created or referenced security group ID |
