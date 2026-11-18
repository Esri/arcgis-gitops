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
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.10"
    }
  }
}

data "aws_region" "current" {}

data "aws_ssm_parameter" "logs" {
  name = "/arcgis/${var.enterprise_id}/s3/logs"
}

locals {
  commands = <<-POWERSHELL
    $ErrorActionPreference = 'Stop'
    try {
      & {
    ${file("${path.module}/scripts/prepare_os_disk.ps1")}
      } -ExpectedSizeGiB ${var.os_disk_size}
      & {
    ${file("${path.module}/scripts/prepare_data_disk.ps1")}
      } -VolumeId '${var.data_volume_id}' -ExpectedSizeGiB ${var.data_disk_size}
      exit 0
    } catch {
      [Console]::Error.WriteLine($_.ToString())
      exit 1
    }
  POWERSHELL
}

resource "terraform_data" "readiness" {
  triggers_replace = {
    always_run     = timestamp()
    instance_id    = var.instance_id
    data_volume_id = var.data_volume_id
    os_size_gib    = var.os_disk_size
    data_size_gib  = var.data_disk_size
    script_sha256  = sha256(local.commands)
  }

  provisioner "local-exec" {
    environment = {
      AWS_DEFAULT_REGION = data.aws_region.current.region
    }
    command = "python -m ssm_wait_for_target_instances -s ${var.enterprise_id} -d ${var.deployment_id} -m ${var.machine_role}"
  }
}

resource "aws_ssm_association" "prepare" {
  name                             = "AWS-RunPowerShellScript"
  association_name                 = "${var.enterprise_id}-${var.deployment_id}-${var.machine_role}-disks"
  wait_for_success_timeout_seconds = 1200

  targets {
    key    = "InstanceIds"
    values = [var.instance_id]
  }

  parameters = {
    executionTimeout = "600"
    commands         = local.commands
  }

  output_location {
    s3_bucket_name = nonsensitive(data.aws_ssm_parameter.logs.value)
    s3_key_prefix  = "${var.deployment_id}/disk-preparation/${var.machine_role}"
  }

  lifecycle {
    replace_triggered_by = [terraform_data.readiness]
    precondition {
      condition     = length(local.commands) <= 64000
      error_message = "Disk preparation exceeds the SSM command payload limit."
    }
  }

  tags = {
    ArcGISAutomation   = "arcgis-gitops"
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}
