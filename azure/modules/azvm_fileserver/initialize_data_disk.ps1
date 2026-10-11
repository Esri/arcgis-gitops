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

$ErrorActionPreference = 'Stop'

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

function Get-TargetDisk {
    $disks = @(Get-Disk | Where-Object {
        -not $_.IsBoot -and -not $_.IsSystem -and $_.Location -match '\bLUN 0\b'
    })
    if ($disks.Count -ne 1) {
        throw "Expected exactly one non-OS disk at LUN 0, found $($disks.Count)."
    }
    $disks[0]
}

function Get-VolumeTarget($Volume) {
    if ($Volume.Path -notmatch '^\\\\\?\\(Volume\{[^}]+\})\\$') {
        throw 'Volume has no recognized mount-manager path; refusing to modify it.'
    }
    $target = [ArcGISDrivePaths]::GetTarget($Matches[1])
    if (-not $target) { throw 'Volume mount-manager target is missing.' }
    $target
}

$disk = Get-TargetDisk
if ([string]::IsNullOrWhiteSpace($disk.UniqueId)) { throw 'LUN 0 disk identity is missing.' }
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
if ($disk.IsOffline) {
    Write-Output "Bringing the identified LUN 0 disk $($disk.Number) online for partition inspection."
    Set-Disk -Number $disk.Number -IsOffline $false
}
$inventory = Get-DriveInventory
$partitions = @($inventory.Partitions | Where-Object {
    $_.DiskNumber -eq $disk.Number -and $_.Type -ne 'Reserved'
})
if ($partitions.Count -gt 1) { throw 'LUN 0 has multiple data partitions; refusing to choose one.' }
if ($partitions.Count -eq 0 -and $disk.PartitionStyle -ne 'RAW') {
    throw 'Initialized LUN 0 disk has no recognized data partition; refusing to modify it.'
}
if ($partitions.Count -eq 1) {
    if ($partitions[0].Type -ne 'Basic' -or $partitions[0].IsBoot -or $partitions[0].IsSystem) {
        throw 'LUN 0 partition is not an unprotected data partition; refusing to modify it.'
    }
    $existingVolumes = @($partitions[0] | Get-Volume)
    if ($existingVolumes.Count -ne 1 -or $existingVolumes[0].FileSystemType -notin @('NTFS', 'RAW', 'Unknown')) {
        throw 'Existing LUN 0 volume is missing or uses an unsupported filesystem; refusing to format it.'
    }
}

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
            throw 'D: device mapping does not match its partition volume; refusing to change it.'
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
        if ($dosTargetD -notmatch '^\\Device\\CdRom\d+$') {
            throw 'D: device mapping does not match an optical volume; refusing to change it.'
        }
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
        Write-Output "Moving disk $($movePartition.DiskNumber) partition $($movePartition.PartitionNumber) from D: to ${freeLetter}:."
        Set-Partition -DiskNumber $movePartition.DiskNumber -PartitionNumber $movePartition.PartitionNumber -NewDriveLetter $freeLetter
    } else {
        Write-Output "Moving optical drive $($opticalD[0].DeviceID) from D: to ${freeLetter}:."
        # DiskPart addresses optical volumes even when no media is inserted.
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
        @($inventory.OpticalDrives | Where-Object {
            $_.DeviceID -eq $opticalD[0].DeviceID -and $_.Drive -eq "${freeLetter}:"
        })
    }
    if ($inventory.Letters -contains 'D' -or @($moved).Count -ne 1) {
        throw "D: was not released or relocation was not verified. $output"
    }
}

if ($disk.IsReadOnly) { Set-Disk -Number $disk.Number -IsReadOnly $false }
if ($disk.PartitionStyle -eq 'RAW') { Initialize-Disk -Number $disk.Number -PartitionStyle GPT | Out-Null }
if ($partitions.Count -eq 0) {
    $partition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -DriveLetter D
} else {
    $partition = $partitions[0]
    if ($partition.DriveLetter -ne 'D') {
        Set-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -NewDriveLetter D
    }
    $partition = Get-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
}
if (@($partition).Count -ne 1 -or $partition.DiskNumber -ne $disk.Number -or $partition.DriveLetter -ne 'D') {
    throw 'Partition assignment did not return the intended D: partition; refusing to format it.'
}
$volumes = @($partition | Get-Volume)
if ($volumes.Count -ne 1) { throw 'Expected one volume on the intended partition; refusing to format it.' }
if ($volumes[0].FileSystemType -in @('RAW', 'Unknown')) {
    $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'ArcGISData' -Confirm:$false | Out-Null
} elseif ($volumes[0].FileSystemType -ne 'NTFS') {
    throw 'Unsupported filesystem on LUN 0; refusing to format it.'
}

$verifiedDisk = Get-TargetDisk
$inventory = Get-DriveInventory
$verifiedPartitions = @($inventory.Partitions | Where-Object { $_.DriveLetter -eq 'D' })
$verifiedVolumes = @($inventory.Volumes | Where-Object { $_.DriveLetter -eq 'D' })
if ($verifiedDisk.Number -ne $disk.Number -or $verifiedDisk.UniqueId -ne $disk.UniqueId -or
    $verifiedDisk.IsOffline -or $verifiedDisk.IsReadOnly -or
    $verifiedPartitions.Count -ne 1 -or $verifiedPartitions[0].DiskNumber -ne $disk.Number -or
    $verifiedPartitions[0].PartitionNumber -ne $partition.PartitionNumber -or
    $verifiedVolumes.Count -ne 1 -or $verifiedVolumes[0].FileSystemType -ne 'NTFS' -or
    [ArcGISDrivePaths]::GetTarget('D:') -ne (Get-VolumeTarget $verifiedVolumes[0]) -or
    ($inventory.OpticalDrives | Where-Object { $_.Drive -eq 'D:' }) -or
    ($inventory.LogicalDisks | Where-Object { $_.DeviceID -eq 'D:' -and $_.DriveType -ne 3 }) -or
    ($inventory.PSDrives | Where-Object { $_.Name -eq 'D' -and ($_.Root -ne 'D:\' -or $_.DisplayRoot) })) {
    throw 'Final D: verification failed: expected writable NTFS on the intended LUN 0 disk.'
}

$probe = Join-Path 'D:\' ("arcgis-disk-probe-{0}.tmp" -f [guid]::NewGuid())
$value = [guid]::NewGuid().ToString()
try {
    Set-Content -LiteralPath $probe -Value $value -NoNewline
    if ((Get-Content -LiteralPath $probe -Raw) -ne $value) { throw 'D: write/read probe failed.' }
} finally {
    if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force }
}
Write-Output "Verified writable NTFS D: on LUN 0 disk $($disk.Number) ($($disk.UniqueId))."
