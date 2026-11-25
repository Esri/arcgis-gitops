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
      function Read-ArcGISEc2Metadata($Path, $Method, $Header, $Value) {
        $request = [Net.HttpWebRequest]::Create("http://169.254.169.254/latest/$Path")
        $request.Method = $Method
        $request.Proxy = $null
        $request.AllowAutoRedirect = $false
        $request.Timeout = 5000
        $request.ReadWriteTimeout = 5000
        $request.Headers.Add($Header, $Value)
        if ($Method -eq 'PUT') { $request.ContentLength = 0 }
        $response = $request.GetResponse()
        try {
          if ($response.StatusCode -ne [Net.HttpStatusCode]::OK) { throw 'EC2 metadata request failed.' }
          $reader = [IO.StreamReader]::new($response.GetResponseStream())
          try { $reader.ReadToEnd().Trim() } finally { $reader.Dispose() }
        } finally { $response.Dispose() }
      }
      # Tag membership may change after dispatch; only the prevalidated guests may write.
      $token = Read-ArcGISEc2Metadata 'api/token' 'PUT' 'X-aws-ec2-metadata-token-ttl-seconds' '60'
      $instanceId = Read-ArcGISEc2Metadata 'meta-data/instance-id' 'GET' 'X-aws-ec2-metadata-token' $token
      if ($instanceId -cnotmatch '^i-[0-9a-f]+$') { throw 'IMDSv2 did not return a valid EC2 instance ID.' }
      $targets = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__ARCGIS_VALIDATED_TARGETS__')) | ConvertFrom-Json
      $target = $targets.PSObject.Properties[$instanceId]
      if ($null -eq $target) { throw "Instance $instanceId is not in the validated target set." }
      $volumeId = [string]$target.Value
    ${file("${path.module}/scripts/image_identity.ps1")}
    ${file("${path.module}/scripts/replace_sid_in_descriptor.ps1")}
    ${file("${path.module}/scripts/reconcile_image_sid.ps1")}
      function Invoke-ArcGISDataDisk {
    ${file("${path.module}/scripts/prepare_data_disk.ps1")}
      }
      $diskArgs = @{
        VolumeId = $volumeId
        InstanceId = $instanceId
        ExpectedSizeGiB = ${var.data_disk_size}
        ImageRole = '${var.image_role}'
        AllowDataDiskRebind = ${var.allow_data_disk_rebind ? "$true" : "$false"}
        EncodedExpectedAccount = '${base64encode(coalesce(var.expected_account, "-"))}'
      }
      Invoke-ArcGISDataDisk @diskArgs -PreflightOnly
      if ('${var.expected_account == null ? "false" : "true"}' -eq 'false') {
        & {
    ${file("${path.module}/scripts/prepare_os_disk.ps1")}
        } -ExpectedSizeGiB ${var.os_disk_size}
      }
      Invoke-ArcGISDataDisk @diskArgs ${var.expected_account == null ? "" : "-VerifyOnly"}
      ${var.fileserver_private_dns == null ? "" : "& {\n${var.fileserver_registry_script}\n} -EncodedPrivateDns '${base64encode(coalesce(var.fileserver_private_dns, "-"))}'"}
      exit 0
    } catch {
      [Console]::Error.WriteLine($_.ToString())
      exit 1
    }
  POWERSHELL
}

removed {
  from = terraform_data.readiness
  lifecycle {
    destroy = true
  }
}

removed {
  from = aws_ssm_association.prepare
  lifecycle {
    destroy = true
  }
}

resource "terraform_data" "prepare_with_logs" {
  count            = 1
  triggers_replace = [timestamp(), sha256(local.commands)]

  provisioner "local-exec" {
    command = "python -u -m ssm_run_windows_infrastructure"
    environment = {
      AWS_DEFAULT_REGION      = data.aws_region.current.region
      ARCGIS_ENTERPRISE_ID    = var.enterprise_id
      ARCGIS_DEPLOYMENT_ID    = var.deployment_id
      ARCGIS_ROLE             = var.machine_role
      ARCGIS_DATA_DISK_SIZE   = tostring(var.data_disk_size)
      ARCGIS_DATA_SNAPSHOT_ID = coalesce(var.expected_snapshot_id, "-")
      ARCGIS_LOG_BUCKET       = nonsensitive(data.aws_ssm_parameter.logs.value)
      ARCGIS_REPLAY_LOGS      = tostring(var.log_to_apply)
      ARCGIS_POWERSHELL       = base64gzip(local.commands)
    }
  }

}
