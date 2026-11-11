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

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^vol-[0-9a-f]+$')]
    [string]$VolumeId,
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 65536)]
    [long]$ExpectedSizeGiB
)

$ErrorActionPreference = 'Stop'

function Get-DataDiskState {
    $disks = @(Get-Disk | Where-Object {
        $serial = ([string]$_.SerialNumber).Trim() -replace '_[0-9]+[.]?$', '' -replace '[^A-Za-z0-9]', ''
        $serial -eq ($VolumeId -replace '-', '')
    })
    if ($disks.Count -ne 1) { throw 'Expected exactly one disk matching the file-server EBS volume.' }
    $disk = $disks[0]
    if ($disk.IsBoot -or $disk.IsSystem -or $disk.IsOffline -or $disk.IsReadOnly -or
        $disk.PartitionStyle -ne 'GPT' -or [string]::IsNullOrWhiteSpace($disk.UniqueId) -or
        $disk.Size -lt ($ExpectedSizeGiB * 1GB)) {
        throw 'File-server disk must be an online, writable, non-OS GPT disk with the requested capacity.'
    }
    $partitions = @(Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne 'Reserved' })
    if ($partitions.Count -ne 1 -or $partitions[0].Type -ne 'Basic' -or
        $partitions[0].IsBoot -or $partitions[0].IsSystem -or $partitions[0].DriveLetter -ne 'D') {
        throw 'Expected the existing, unprotected D: data partition; initialization and formatting are prohibited.'
    }
    $partition = $partitions[0]
    $drivePartitions = @(Get-Partition -DriveLetter D)
    $volumes = @($partition | Get-Volume)
    $driveVolumes = @(Get-Volume -DriveLetter D)
    $logicalDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='D:'")
    $drive = Get-PSDrive -Name D -PSProvider FileSystem
    if ($drivePartitions.Count -ne 1 -or $drivePartitions[0].DiskNumber -ne $disk.Number -or
        $drivePartitions[0].PartitionNumber -ne $partition.PartitionNumber -or
        $volumes.Count -ne 1 -or $volumes[0].FileSystemType -ne 'NTFS' -or
        [string]::IsNullOrWhiteSpace($volumes[0].UniqueId) -or
        $driveVolumes.Count -ne 1 -or $driveVolumes[0].UniqueId -ne $volumes[0].UniqueId -or
        $logicalDisks.Count -ne 1 -or $logicalDisks[0].DriveType -ne 3 -or
        $drive.Root -ne 'D:\' -or $drive.DisplayRoot) {
        throw 'D: is not unambiguously mapped to NTFS on the intended EBS partition.'
    }
    [pscustomobject]@{ Disk = $disk; Partition = $partition; Volume = $volumes[0] }
}

Update-HostStorageCache
$before = Get-DataDiskState
$supported = Get-PartitionSupportedSize -DiskNumber $before.Disk.Number -PartitionNumber $before.Partition.PartitionNumber
$targetSize = $supported.SizeMax - ($supported.SizeMax % 1MB)
if ($targetSize -lt ($before.Disk.Size - $before.Partition.Offset - 1MB)) {
    throw 'The supported partition maximum cannot expose the requested disk capacity.'
}
if ($targetSize -ge ($before.Partition.Size + 1MB)) {
    Resize-Partition -DiskNumber $before.Disk.Number -PartitionNumber $before.Partition.PartitionNumber -Size $targetSize
}

$after = Get-DataDiskState
$supported = Get-PartitionSupportedSize -DiskNumber $after.Disk.Number -PartitionNumber $after.Partition.PartitionNumber
if ($after.Disk.UniqueId -ne $before.Disk.UniqueId -or $after.Disk.Number -ne $before.Disk.Number -or
    $after.Partition.PartitionNumber -ne $before.Partition.PartitionNumber -or
    $after.Volume.UniqueId -ne $before.Volume.UniqueId -or
    $after.Partition.Size -lt $before.Partition.Size -or
    ($supported.SizeMax - $after.Partition.Size) -ge 1MB -or
    $after.Partition.Size -lt ($after.Disk.Size - $after.Partition.Offset - 1MB) -or
    $after.Volume.Size -lt ($after.Partition.Size - 1MB)) {
    throw 'File-server capacity verification failed after partition growth.'
}

$probe = 'D:\arcgis-disk-probe-{0}.tmp' -f [guid]::NewGuid()
$value = [guid]::NewGuid().ToString()
try {
    Set-Content -LiteralPath $probe -Value $value -NoNewline
    if ((Get-Content -LiteralPath $probe -Raw) -ne $value) { throw 'D: write/read probe failed.' }
} finally {
    if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force }
}
Write-Output "Verified $VolumeId NTFS D: growth from $($before.Partition.Size) to $($after.Partition.Size) bytes on a $($after.Disk.Size)-byte disk."