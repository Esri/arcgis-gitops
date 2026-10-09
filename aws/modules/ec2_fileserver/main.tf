# Copyright 2026 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }
}

data "aws_ssm_parameter" "ami" {
  count = var.fileserver_deployment_id == null ? 1 : 0
  name  = "/arcgis/${var.enterprise_id}/images/${var.deployment_id}/fileserver"
}

data "aws_ami" "fileserver" {
  count  = var.fileserver_deployment_id == null ? 1 : 0
  owners = ["self"]

  filter {
    name   = "image-id"
    values = [nonsensitive(data.aws_ssm_parameter.ami[0].value)]
  }
}

data "aws_vpc" "deployment" {
  id = var.vpc_id
}

data "aws_ssm_parameter" "shared_security_group_id" {
  count = var.fileserver_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/security-group-id"
}

data "aws_ssm_parameter" "shared_private_dns" {
  count = var.fileserver_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/private-dns"
}

data "aws_ssm_parameter" "shared_instance_id" {
  count = var.fileserver_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/instance-id"
}

data "aws_ssm_parameter" "shared_instance_arn" {
  count = var.fileserver_deployment_id == null ? 0 : 1
  name  = "/arcgis/${var.enterprise_id}/${var.fileserver_deployment_id}/fileserver/instance-arn"
}

locals {
  create_fileserver = var.fileserver_deployment_id == null
  private_dns       = local.create_fileserver ? "fileserver.${var.deployment_id}.${var.enterprise_id}.internal" : nonsensitive(data.aws_ssm_parameter.shared_private_dns[0].value)
  security_group_id = local.create_fileserver ? aws_security_group.fileserver[0].id : nonsensitive(data.aws_ssm_parameter.shared_security_group_id[0].value)
  instance_id       = local.create_fileserver ? aws_instance.fileserver[0].id : nonsensitive(data.aws_ssm_parameter.shared_instance_id[0].value)
  instance_arn      = local.create_fileserver ? aws_instance.fileserver[0].arn : nonsensitive(data.aws_ssm_parameter.shared_instance_arn[0].value)
  data_snapshot_id  = local.create_fileserver ? one([for device in data.aws_ami.fileserver[0].block_device_mappings : lookup(device.ebs, "snapshot_id", null) if device.device_name == "/dev/sdf"]) : null
  data_volume_id    = local.create_fileserver ? one([for device in aws_instance.fileserver[0].ebs_block_device : device.volume_id if device.device_name == "/dev/sdf"]) : null
}

resource "aws_security_group" "fileserver" {
  count       = local.create_fileserver ? 1 : 0
  name        = "${var.enterprise_id}-${var.deployment_id}-fileserver"
  description = "Dedicated security boundary for the Windows file-server VM"
  vpc_id      = var.vpc_id

  egress {
    description = "AWS control plane and software repositories over HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "VPC DNS resolver over TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["${cidrhost(data.aws_vpc.deployment.cidr_block, 2)}/32"]
  }

  egress {
    description = "VPC DNS resolver over UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["${cidrhost(data.aws_vpc.deployment.cidr_block, 2)}/32"]
  }

  egress {
    description = "Amazon Time Sync Service"
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["169.254.169.123/32"]
  }

  tags = {
    Name              = "${var.enterprise_id}/${var.deployment_id}/fileserver"
    ArcGISMachineRole = "fileserver"
  }
}

resource "aws_vpc_security_group_ingress_rule" "smb" {
  security_group_id            = local.security_group_id
  description                  = "SMB from deployment machines"
  from_port                    = 445
  to_port                      = 445
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.referenced_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "rpc" {
  security_group_id            = local.security_group_id
  description                  = "RPC from deployment machines"
  from_port                    = 135
  to_port                      = 139
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.referenced_security_group_id
}

resource "aws_network_interface" "fileserver" {
  count           = local.create_fileserver ? 1 : 0
  subnet_id       = var.subnet_id
  security_groups = [aws_security_group.fileserver[0].id]

  tags = {
    Name = "${var.enterprise_id}/${var.deployment_id}/fileserver"
  }
}

resource "aws_instance" "fileserver" {
  count                = local.create_fileserver ? 1 : 0
  ami                  = nonsensitive(data.aws_ssm_parameter.ami[0].value)
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = var.iam_instance_profile
  monitoring           = true

  primary_network_interface {
    network_interface_id = aws_network_interface.fileserver[0].id
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 256
    encrypted   = true
    iops        = 3000
    throughput  = 125
  }

  ebs_block_device {
    device_name           = "/dev/sdf"
    snapshot_id           = local.data_snapshot_id
    encrypted             = local.data_snapshot_id == null ? true : null
    volume_size           = var.data_volume_size
    volume_type           = var.data_volume_type
    iops                  = contains(["gp3", "io1", "io2"], var.data_volume_type) ? var.data_volume_iops : null
    throughput            = var.data_volume_type == "gp3" ? var.data_volume_throughput : null
    delete_on_termination = true
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for device in data.aws_ami.fileserver[0].block_device_mappings :
        lookup(device.ebs, "snapshot_id", "") != "" && tonumber(lookup(device.ebs, "volume_size", "0")) <= var.data_volume_size
        if device.device_name == "/dev/sdf"
      ])
      error_message = "An AMI data mapping must contain a snapshot that fits the configured data capacity; blank replacement and shrink are prohibited."
    }
  }

  user_data = <<-EOF
  <powershell>
  $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
  if (-not (Test-Path $registryPath)) {
    New-Item $registryPath -Force
  }
  New-ItemProperty -Path $registryPath -Name "BackConnectionHostNames" `
                   -Value @($env:COMPUTERNAME, "${local.private_dns}", "localhost", "127.0.0.1") `
                   -PropertyType MultiString -Force
  </powershell>
  EOF

  user_data_replace_on_change = false

  tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/fileserver"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISTemplateId   = var.arcgis_template_id
    ArcGISVersion      = var.arcgis_version
    ArcGISMachineRole  = "fileserver"
    ArcGISAutomation   = "arcgis-gitops"
  }

  volume_tags = {
    Name               = "${var.enterprise_id}/${var.deployment_id}/fileserver"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISMachineRole  = "fileserver"
    ArcGISAutomation   = "arcgis-gitops"
  }
}

removed {
  from = aws_ebs_volume.data

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_volume_attachment.data

  lifecycle {
    destroy = false
  }
}

resource "aws_ssm_association" "initialize_data_disk" {
  count                            = local.create_fileserver ? 1 : 0
  name                             = "AWS-RunPowerShellScript"
  wait_for_success_timeout_seconds = 1200

  targets {
    key    = "InstanceIds"
    values = [aws_instance.fileserver[0].id]
  }

  parameters = {
    commands = join("\n", [
      "$ErrorActionPreference = 'Stop'",
      "$volumeId = '${replace(local.data_volume_id, "-", "")}'",
      "$recoverData = ${local.data_snapshot_id != null ? "$true" : "$false"}",
      "$dataDisks = @(Get-Disk | Where-Object { ((([string]$_.SerialNumber).Trim() -replace '_[0-9]+[.]?$', '' -replace '[^A-Za-z0-9]', '') -eq $volumeId) })",
      "if ($dataDisks.Count -ne 1) { throw ('Expected exactly one disk for EBS volume ${local.data_volume_id}, found {0}. No disk was modified.' -f $dataDisks.Count) }",
      "$dataDisk = $dataDisks[0]",
      "$driveD = @(Get-Partition -DriveLetter D -ErrorAction SilentlyContinue)",
      "if ($driveD.Count -gt 0 -and ($driveD.Count -ne 1 -or $driveD[0].DiskNumber -ne $dataDisk.Number)) { throw ('Drive D: is already assigned to disk {0}; expected EBS data disk {1}. No disk was modified.' -f $driveD[0].DiskNumber, $dataDisk.Number) }",
      "if ($recoverData -and $dataDisk.PartitionStyle -eq 'RAW') { throw 'Recovered data disk is RAW; refusing to initialize or format it.' }",
      "if ($dataDisk.IsOffline) { Set-Disk -Number $dataDisk.Number -IsOffline $false }",
      "if ($dataDisk.IsReadOnly) { Set-Disk -Number $dataDisk.Number -IsReadOnly $false }",
      "if ($dataDisk.PartitionStyle -eq 'RAW') { Initialize-Disk -Number $dataDisk.Number -PartitionStyle GPT | Out-Null }",
      "$partitions = @(Get-Partition -DiskNumber $dataDisk.Number | Where-Object { $_.Type -ne 'Reserved' })",
      "if ($recoverData -and $partitions.Count -ne 1) { throw 'Recovered data disk must contain exactly one existing data partition.' }",
      "if ($partitions.Count -eq 0) { $partition = New-Partition -DiskNumber $dataDisk.Number -UseMaximumSize -DriveLetter D } elseif ($partitions.Count -eq 1) { $partition = $partitions[0]; if ($partition.DriveLetter -ne 'D') { Set-Partition -DiskNumber $dataDisk.Number -PartitionNumber $partition.PartitionNumber -NewDriveLetter D; $partition = Get-Partition -DiskNumber $dataDisk.Number -PartitionNumber $partition.PartitionNumber } } else { throw ('EBS data disk {0} has {1} data partitions; refusing to choose one.' -f $dataDisk.Number, $partitions.Count) }",
      "$volume = $partition | Get-Volume -ErrorAction SilentlyContinue",
      "if ($recoverData -and ($null -eq $volume -or $volume.FileSystemType -ne 'NTFS')) { throw 'Recovered data partition must contain NTFS; refusing to format it.' }",
      "if ($null -eq $volume -or [string]::IsNullOrWhiteSpace([string]$volume.FileSystemType) -or $volume.FileSystemType -eq 'Unknown') { $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'ArcGISData' -Confirm:$false | Out-Null } elseif ($volume.FileSystemType -ne 'NTFS') { throw ('EBS data disk {0} uses unsupported filesystem {1}; refusing to format it.' -f $dataDisk.Number, $volume.FileSystemType) }"
    ])
  }
}

resource "aws_route53_record" "fileserver" {
  count   = local.create_fileserver ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = "fileserver.${var.deployment_id}"
  type    = "A"
  ttl     = 300
  records = [aws_instance.fileserver[0].private_ip]
}

resource "aws_ssm_parameter" "security_group_id" {
  count       = local.create_fileserver ? 1 : 0
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/security-group-id"
  type        = "String"
  value       = aws_security_group.fileserver[0].id
  description = "Dedicated Windows file-server security group ID"
}

resource "aws_ssm_parameter" "private_dns" {
  count       = local.create_fileserver ? 1 : 0
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/private-dns"
  type        = "String"
  value       = local.private_dns
  description = "Private DNS name of the dedicated Windows file-server VM"
}

resource "aws_ssm_parameter" "instance_id" {
  count       = local.create_fileserver ? 1 : 0
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/instance-id"
  type        = "String"
  value       = aws_instance.fileserver[0].id
  description = "Dedicated Windows file-server EC2 instance ID"
}

resource "aws_ssm_parameter" "instance_arn" {
  count       = local.create_fileserver ? 1 : 0
  name        = "/arcgis/${var.enterprise_id}/${var.deployment_id}/fileserver/instance-arn"
  type        = "String"
  value       = aws_instance.fileserver[0].arn
  description = "Dedicated Windows file-server EC2 instance ARN"
}

moved {
  from = aws_security_group.fileserver
  to   = aws_security_group.fileserver[0]
}

moved {
  from = aws_network_interface.fileserver
  to   = aws_network_interface.fileserver[0]
}

moved {
  from = aws_instance.fileserver
  to   = aws_instance.fileserver[0]
}

moved {
  from = aws_ssm_association.initialize_data_disk
  to   = aws_ssm_association.initialize_data_disk[0]
}

moved {
  from = aws_route53_record.fileserver
  to   = aws_route53_record.fileserver[0]
}

moved {
  from = aws_ssm_parameter.security_group_id
  to   = aws_ssm_parameter.security_group_id[0]
}

moved {
  from = aws_ssm_parameter.private_dns
  to   = aws_ssm_parameter.private_dns[0]
}