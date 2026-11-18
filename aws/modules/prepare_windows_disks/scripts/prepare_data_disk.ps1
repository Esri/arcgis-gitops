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

function Get-TargetDisk {
    $disks = @(Get-Disk | Where-Object {
        $serial = ([string]$_.SerialNumber).Trim() -replace '_[0-9]+[.]?$', '' -replace '[^A-Za-z0-9]', ''
        $serial -eq ($VolumeId -replace '-', '')
    })
    if ($disks.Count -ne 1) { throw "Expected exactly one disk matching EBS volume $VolumeId; found $($disks.Count)." }
    $disk = $disks[0]
    if ($disk.IsBoot -or $disk.IsSystem -or $disk.HealthStatus -ne 'Healthy' -or
        $disk.PartitionStyle -ne 'GPT' -or [string]::IsNullOrWhiteSpace($disk.UniqueId) -or
        $disk.Size -lt ($ExpectedSizeGiB * 1GB - 1MB)) {
        throw "Data disk $VolumeId must be an identified healthy non-OS GPT disk with the requested capacity. Initialization and formatting are prohibited."
    }
    $disk
}

function Get-DriveInventory {
    $partitions = @(Get-Partition)
    $volumes = @(Get-Volume)
    $logicalDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk)
    $opticalDrives = @(Get-CimInstance -ClassName Win32_CDROMDrive)
    $psDrives = @(Get-PSDrive -PSProvider FileSystem)
    $letters = @($partitions.DriveLetter) + @($volumes.DriveLetter) +
        @($logicalDisks.DeviceID | Where-Object { $_ } | ForEach-Object { $_.TrimEnd(':') }) +
        @($opticalDrives.Drive | Where-Object { $_ } | ForEach-Object { $_.TrimEnd(':') }) +
        @($psDrives.Name)
    foreach ($letter in [char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ') {
        if ([ArcGISDrivePaths]::GetTarget("${letter}:")) { $letters += [string]$letter }
    }
    [pscustomobject]@{
        Partitions = $partitions
        Volumes = $volumes
        LogicalDisks = $logicalDisks
        OpticalDrives = $opticalDrives
        PSDrives = $psDrives
        Letters = @($letters | Where-Object { $_ } | Select-Object -Unique)
    }
}

function Get-VolumeTarget($Volume) {
    if ($Volume.Path -notmatch '^\\\\\?\\(Volume\{[^}]+\})\\$') {
        throw 'Volume has no recognized mount-manager path; refusing to modify it.'
    }
    $target = [ArcGISDrivePaths]::GetTarget($Matches[1])
    if (-not $target) { throw 'Volume mount-manager target is missing.' }
    $target
}

Update-HostStorageCache
$disk = Get-TargetDisk
if (-not ('ArcGISDrivePaths' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ArcGISDrivePaths {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint QueryDosDevice(string name, StringBuilder target, int size);
    public static string GetTarget(string name) {
        var target = new StringBuilder(32768);
        if (QueryDosDevice(name, target, target.Capacity) != 0) return target.ToString().Split('\0')[0];
        int error = Marshal.GetLastWin32Error();
        if (error == 2) return null;
        throw new System.ComponentModel.Win32Exception(error);
    }
}
'@
}
if ($disk.IsOffline) { Set-Disk -Number $disk.Number -IsOffline $false }
$inventory = Get-DriveInventory
$partitions = @($inventory.Partitions | Where-Object { $_.DiskNumber -eq $disk.Number -and $_.Type -ne 'Reserved' })
if ($partitions.Count -ne 1 -or $partitions[0].Type -ne 'Basic' -or
    $partitions[0].IsBoot -or $partitions[0].IsSystem) {
    throw 'Expected one existing unprotected data partition; initialization and formatting are prohibited.'
}
$partition = $partitions[0]
$volumes = @($partition | Get-Volume)
if ($volumes.Count -ne 1 -or $volumes[0].FileSystemType -ne 'NTFS' -or
    $volumes[0].HealthStatus -ne 'Healthy' -or [string]::IsNullOrWhiteSpace($volumes[0].UniqueId)) {
    throw 'Expected one healthy identified NTFS data volume; formatting is prohibited.'
}
$volume = $volumes[0]
$driveD = @($inventory.Partitions | Where-Object { $_.DriveLetter -eq 'D' })
$opticalD = @($inventory.OpticalDrives | Where-Object { $_.Drive -eq 'D:' })
$logicalD = @($inventory.LogicalDisks | Where-Object { $_.DeviceID -eq 'D:' })
$volumeD = @($inventory.Volumes | Where-Object { $_.DriveLetter -eq 'D' })
$psDriveD = @($inventory.PSDrives | Where-Object { $_.Name -eq 'D' })
if ($driveD.Count -gt 1 -or $opticalD.Count -gt 1 -or $logicalD.Count -gt 1 -or $volumeD.Count -gt 1 -or
    ($driveD.Count -eq 1 -and $opticalD.Count -ne 0) -or
    ($psDriveD | Where-Object { $_.Root -ne 'D:\' -or $_.DisplayRoot })) {
    throw 'Ambiguous or redirected D: mapping; refusing to change it.'
}
$movePartition = $null
$moveOptical = $false
$dosTargetD = [ArcGISDrivePaths]::GetTarget('D:')
if ($inventory.Letters -contains 'D') {
    if ($driveD.Count -eq 1 -and ($logicalD | Where-Object { $_.DriveType -ne 3 }).Count -eq 0) {
        if ($volumeD.Count -ne 1 -or $dosTargetD -ne (Get-VolumeTarget $volumeD[0])) {
            throw 'D: device mapping does not match its partition volume.'
        }
        if ($driveD[0].DiskNumber -ne $disk.Number) {
            $occupiedDisk = Get-Disk -Number $driveD[0].DiskNumber
            if ($occupiedDisk.IsBoot -or $occupiedDisk.IsSystem -or $driveD[0].IsBoot -or $driveD[0].IsSystem) {
                throw 'Drive D: belongs to an OS/system disk; refusing to move it.'
            }
            $movePartition = $driveD[0]
        }
    } elseif ($driveD.Count -eq 0 -and $opticalD.Count -eq 1 -and
        ($logicalD | Where-Object { $_.DriveType -ne 5 }).Count -eq 0) {
        if ($dosTargetD -notmatch '^\\Device\\CdRom\d+$') { throw 'D: does not match an optical volume.' }
        $moveOptical = $true
    } else {
        throw 'Unsupported D: occupant; refusing to change it.'
    }
}
if ($movePartition -or $moveOptical) {
    $freeLetter = @('T', 'U', 'V', 'W', 'X', 'Y', 'Z') |
        Where-Object { $inventory.Letters -notcontains $_ } | Select-Object -First 1
    if (-not $freeLetter) { throw 'No free drive letter for the existing D: device.' }
    if ($movePartition) {
        Set-Partition -DiskNumber $movePartition.DiskNumber -PartitionNumber $movePartition.PartitionNumber -NewDriveLetter $freeLetter
    } else {
        $output = @('select volume D', 'remove letter=D', "assign letter=$freeLetter", 'exit') | diskpart.exe
        if ($LASTEXITCODE -ne 0) { throw "Optical drive reassignment failed: $output" }
    }
    $inventory = Get-DriveInventory
    $moved = if ($movePartition) {
        @($inventory.Partitions | Where-Object {
            $_.DiskNumber -eq $movePartition.DiskNumber -and $_.PartitionNumber -eq $movePartition.PartitionNumber -and
            $_.DriveLetter -eq $freeLetter
        })
    } else {
        @($inventory.OpticalDrives | Where-Object { $_.DeviceID -eq $opticalD[0].DeviceID -and $_.Drive -eq "${freeLetter}:" })
    }
    if ($inventory.Letters -contains 'D' -or @($moved).Count -ne 1) {
        throw 'D: was not released or relocation was not verified.'
    }
}
if ($disk.IsReadOnly) { Set-Disk -Number $disk.Number -IsReadOnly $false }
if ($partition.DriveLetter -ne 'D') {
    Set-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -NewDriveLetter D
}
$partition = Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
if (@($partition).Count -ne 1 -or $partition.DriveLetter -ne 'D') { throw 'D: assignment failed.' }
$supported = Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
$targetSize = [long]($supported.SizeMax - ($supported.SizeMax % 1MB))
if ($partition.Offset -lt 0 -or $partition.Size -le 0 -or $supported.SizeMax -lt $partition.Size -or
    $supported.SizeMax -gt ($disk.Size - $partition.Offset) -or
    $targetSize -lt ($disk.Size - $partition.Offset - 1MB)) {
    throw "D: cannot expose the requested disk capacity. diskBytes=$($disk.Size), offset=$($partition.Offset), partitionBytes=$($partition.Size), supportedMax=$($supported.SizeMax)."
}
$originalSize = $partition.Size
if ($targetSize -ge ($partition.Size + 1MB)) {
    Resize-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -Size $targetSize
}
$afterDisk = Get-TargetDisk
$after = Get-DriveInventory
$afterPartitions = @($after.Partitions | Where-Object { $_.DriveLetter -eq 'D' })
$afterVolumes = @($after.Volumes | Where-Object { $_.DriveLetter -eq 'D' })
if ($afterDisk.Number -ne $disk.Number -or $afterDisk.UniqueId -ne $disk.UniqueId -or
    $afterDisk.IsOffline -or $afterDisk.IsReadOnly -or $afterDisk.Size -lt $disk.Size -or
    $afterPartitions.Count -ne 1 -or $afterPartitions[0].DiskNumber -ne $disk.Number -or
    $afterPartitions[0].PartitionNumber -ne $partition.PartitionNumber -or
    $afterPartitions[0].Offset -ne $partition.Offset -or
    $afterPartitions[0].Size -lt $originalSize -or
    ($supported.SizeMax - $afterPartitions[0].Size) -ge 1MB -or
    $afterVolumes.Count -ne 1 -or $afterVolumes[0].UniqueId -ne $volume.UniqueId -or
    $afterVolumes[0].FileSystemType -ne 'NTFS' -or $afterVolumes[0].HealthStatus -ne 'Healthy' -or
    $afterVolumes[0].Size -lt ($afterPartitions[0].Size - 1MB) -or
    $afterVolumes[0].Size -gt $afterPartitions[0].Size -or $afterVolumes[0].Size -lt $volume.Size -or
    [ArcGISDrivePaths]::GetTarget('D:') -ne (Get-VolumeTarget $afterVolumes[0]) -or
    ($after.OpticalDrives | Where-Object { $_.Drive -eq 'D:' }) -or
    ($after.LogicalDisks | Where-Object { $_.DeviceID -eq 'D:' -and $_.DriveType -ne 3 }) -or
    ($after.PSDrives | Where-Object { $_.Name -eq 'D' -and ($_.Root -ne 'D:\' -or $_.DisplayRoot) })) {
    throw 'D: partition/NTFS expansion verification failed or disk identity changed.'
}
$root = Get-Item -LiteralPath 'D:\' -Force
if (-not $root.PSIsContainer -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'D: must be a local directory, not a reparse path.'
}
$sid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
$fullControl = [Security.AccessControl.FileSystemRights]::FullControl
$inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
$acl = Get-Acl -LiteralPath 'D:\'
$rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
if (@($rules | Where-Object {
    $_.IdentityReference.Value -in @($sid.Value, 'S-1-1-0', 'S-1-5-11') -and
    $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and
    ($_.FileSystemRights -band $fullControl) -ne 0
}).Count -gt 0) { throw 'Conflicting Users, Everyone, or Authenticated Users Deny rule on D:.' }
if (@($rules | Where-Object {
    $_.IdentityReference.Value -eq $sid.Value -and
    $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
    ($_.FileSystemRights -band $fullControl) -eq $fullControl -and
    ($_.InheritanceFlags -band $inheritance) -eq $inheritance -and
    $_.PropagationFlags -eq [Security.AccessControl.PropagationFlags]::None
}).Count -eq 0) { throw 'Users Full Control root grant is missing. Rebuild the Windows AMI before deploying.' }
$probe = 'D:\arcgis-disk-probe-{0}.tmp' -f [guid]::NewGuid()
$value = [guid]::NewGuid().ToString()
try {
    Set-Content -LiteralPath $probe -Value $value -NoNewline
    if ((Get-Content -LiteralPath $probe -Raw) -ne $value) { throw 'D: write/read probe failed.' }
} finally {
    if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force }
}
Write-Output "Verified $VolumeId NTFS D: partition $originalSize -> $($afterPartitions[0].Size) bytes on a $($afterDisk.Size)-byte disk. Image-time Users permissions are intact; ACLs and services were not changed."
