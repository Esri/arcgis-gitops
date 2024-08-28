#!powershell

# Copyright 2024 Esri
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

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType

$spec = @{
    options             = @{
        manifest = @{ type = "str" }
    }
    supports_check_mode = $true
}
function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = (ConvertPSObjectToHashtable $property.Value).PSObject.BaseObject
            }

            $hash
        } else {
            $InputObject
        }
    }
}

function DownloadS3File {
    param (
        [Parameter(Mandatory = $true)][string]$bucket,
        [Parameter(Mandatory = $true)][string]$key,
        [Parameter(Mandatory = $true)][string]$filepath,
        [Parameter(Mandatory = $true)][string]$region
    )
    
    try {
        Read-S3Object -BucketName $bucket -Key $key -File $filepath -Region $region | Out-Null
    } catch {
        throw "File '$filepath' download failed. " + $_.Exception.Message
    }
}

function DownloadS3Files {
    param (
        [Parameter(Mandatory = $true)][string]$manifest
    )

    
    $result = [PSCustomObject]@{
        output   = @()
        changed = $false
    }


    $data = ConvertPSObjectToHashtable(Get-Content -Raw $manifest | ConvertFrom-Json)

    if ( -not $data.ContainsKey("arcgis") -or 
        -not $data.arcgis.ContainsKey("repository") -or 
        -not $data.arcgis.repository.ContainsKey("server") -or
        -not $data.arcgis.repository.server.ContainsKey("s3bucket") -or
        -not $data.arcgis.repository.server.ContainsKey("region") -or
        -not $data.arcgis.repository.ContainsKey("local_archives") -or
        -not $data.arcgis.repository.ContainsKey("local_patches") -or
        -not $data.arcgis.repository.ContainsKey("files")) {
        throw 'JSON file format is invalid.'
    }

    $bucketName = $data.arcgis.repository.server.s3bucket
    $region = $data.arcgis.repository.server.region
    $localArchives = $data.arcgis.repository.local_archives
    $localPatches = $data.arcgis.repository.local_patches

    New-Item -Path $localArchives -ItemType Directory -Force | Out-Null
    New-Item -Path $localPatches -ItemType Directory -Force | Out-Null

    $files = $data.arcgis.repository.files

    foreach ($file in $files.keys) {
        $subfolder = if ($files[$file].ContainsKey('subfolder')) { $files[$file].subfolder } else { $null }
        $sha256 = if ($files[$file].ContainsKey('sha256')) { $files[$file].sha256.ToLower() } else { $null }
        $s3Key = if ($subfolder) { "$subfolder/$file" } else { $file }
        $filepath = Join-Path -Path $localArchives -ChildPath $file

        if (!(Test-Path $filepath)) {
            DownloadS3File -bucket $bucketName -key $s3Key -filepath $filepath -region $region
            $result.changed = $true
            $result.output += "File '$filepath' downloaded successfully."
        } else {
            $hash = (Get-FileHash -Path $filepath -Algorithm SHA256).Hash.ToLower()
            if ($hash -ne $sha256) {
                Remove-Item -Path $filepath -Force
                DownloadS3File -bucket $bucketName -key $s3Key -filepath $filepath -region $region
                $result.changed = $true
                $result.output += "File '$filepath' updated."
            } else {
                $result.output += "Local file '$filepath' already exists."
            }
        }
    }

    if ($data.arcgis.repository.ContainsKey("patch_notification")) {
        $patchNotification = $data.arcgis.repository.patch_notification
        $patchesSubfolder = $patchNotification.subfolder
        $patches = $patchNotification.patches

        $keys = Get-S3Object -BucketName $bucketName -KeyPrefix $patchesSubfolder -Region $region 

        foreach ($key in $keys) {
            $basename = Split-Path $key.Key -leaf
            foreach ($patch in $patches) {
                if ($basename -like $patch) {
                    $filepath = Join-Path -Path $localPatches -ChildPath $basename
                    if (!(Test-Path $filepath)) {
                        DownloadS3File -bucket $bucketName -key $key.Key -filepath $filepath -region $region
                        $result.changed = $true
                        $result.output += "File '$filepath' downloaded successfully."
                    } else {
                        $result.output += "Local file '$filepath' already exists."
                    }
                }
            }
        }
    }

    return $result
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$module.Result.changed = $false
$module.Result.output = @()

try {
    $result = DownloadS3Files -manifest $module.Params.manifest
    $module.Result.changed = $result.changed
    $module.Result.output  = $result.output
} catch {
    $module.FailJson($_.Exception.Message)
}

$module.ExitJson()