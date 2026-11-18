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
    [ValidateRange(256, 16384)]
    [int]$ExpectedSizeGiB
)

$ErrorActionPreference = 'Stop'
$tolerance = 1MB
if ($env:SystemDrive -ne 'C:') { throw "Expected the running Windows system drive at C:, found '$env:SystemDrive'." }
Update-HostStorageCache
$partitions = @(Get-Partition -DriveLetter C)
if ($partitions.Count -ne 1) { throw 'Expected exactly one C: partition on the running OS disk.' }
$partition = $partitions[0]
$disks = @(Get-Disk -Number $partition.DiskNumber)
if ($disks.Count -ne 1) { throw 'Expected exactly one backing OS disk for C:.' }
$disk = $disks[0]
if (-not $disk.IsBoot -or -not $partition.IsBoot -or $disk.IsOffline -or $disk.IsReadOnly -or
    $disk.HealthStatus -ne 'Healthy' -or [string]::IsNullOrWhiteSpace($disk.UniqueId) -or
    $disk.PartitionStyle -notin @('GPT', 'MBR')) {
    throw 'C: must belong to an identified, healthy, online writable boot disk with a supported partition table.'
}
if ($disk.PartitionStyle -eq 'MBR' -and $disk.Size -gt 2TB) {
    throw 'The OS disk exceeds the supported MBR capacity. Automatic partition-table conversion is prohibited.'
}
$volumes = @($partition | Get-Volume)
if ($volumes.Count -ne 1 -or $volumes[0].FileSystemType -ne 'NTFS' -or
    $volumes[0].HealthStatus -ne 'Healthy' -or $volumes[0].DriveLetter -ne 'C' -or
    [string]::IsNullOrWhiteSpace($volumes[0].UniqueId)) {
    throw 'C: must contain one healthy identified NTFS OS volume.'
}
$volume = $volumes[0]
$root = Get-Item -LiteralPath 'C:\' -Force
$psDrive = @(Get-PSDrive -Name C -PSProvider FileSystem)
if (-not $root.PSIsContainer -or ($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
    $psDrive.Count -ne 1 -or $psDrive[0].Root -ne 'C:\' -or $psDrive[0].DisplayRoot) {
    throw 'C: must be the local OS volume, not a redirected or reparse path.'
}
if (-not ('ArcGISOSDrivePaths' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class ArcGISOSDrivePaths {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint QueryDosDevice(string name, StringBuilder target, int size);
    public static string GetTarget(string name) {
        var target = new StringBuilder(32768);
        if (QueryDosDevice(name, target, target.Capacity) != 0) return target.ToString().Split('\0')[0];
        throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
    }
}
'@
}
if ($volume.Path -notmatch '^\\\\\?\\(Volume\{[^}]+\})\\$' -or
    [ArcGISOSDrivePaths]::GetTarget('C:') -ne [ArcGISOSDrivePaths]::GetTarget($Matches[1])) {
    throw 'C: device mapping does not match the identified OS volume.'
}

$layout = @(Get-Partition -DiskNumber $disk.Number | Sort-Object Offset)
$supported = Get-PartitionSupportedSize -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber
$diagnostics = "disk=$($disk.Number), diskBytes=$($disk.Size), expectedGiB=$ExpectedSizeGiB, CBytes=$($partition.Size), supportedMax=$($supported.SizeMax); layout=" +
    ($layout | Select-Object PartitionNumber, DriveLetter, Type, Offset, Size, IsBoot, IsSystem | ConvertTo-Json -Compress)
Write-Output "C: expansion preflight: $diagnostics"
if ($disk.Size -lt ([long]$ExpectedSizeGiB * 1GB - $tolerance)) {
    throw "Windows sees less than the configured OS EBS capacity after storage refresh. Check EBS resizing and guest storage inventory. $diagnostics"
}
$targetSize = [long]($supported.SizeMax - ($supported.SizeMax % 1MB))
if ($partition.Offset -lt 0 -or $partition.Size -le 0 -or
    $supported.SizeMax -lt $partition.Size -or $targetSize -gt ($disk.Size - $partition.Offset)) {
    throw "Invalid C: supported size or OS partition extent. $diagnostics"
}
$osEntries = @($layout | Where-Object {
    $_.DiskNumber -eq $disk.Number -and $_.PartitionNumber -eq $partition.PartitionNumber -and
    $_.Offset -eq $partition.Offset -and $_.Size -eq $partition.Size
})
if ($osEntries.Count -ne 1) { throw "C: does not match the refreshed partition layout. $diagnostics" }
$previousEnd = 0L
foreach ($entry in $layout) {
    if ($entry.DiskNumber -ne $disk.Number -or $entry.Offset -lt $previousEnd -or
        $entry.Size -le 0 -or ($entry.Offset + $entry.Size) -gt $disk.Size) {
        throw "Invalid or overlapping OS disk partition layout. $diagnostics"
    }
    $previousEnd = $entry.Offset + $entry.Size
}

# Inspect the unrounded extent so alignment slack is not mistaken for blocked capacity.
$targetEnd = $partition.Offset + $supported.SizeMax
$cursor = $targetEnd
$blockedBytes = 0L
foreach ($entry in @($layout | Where-Object {
    $_.PartitionNumber -ne $partition.PartitionNumber -and $_.Offset -ge ($partition.Offset + $partition.Size)
})) {
    if ($entry.Offset -lt $targetEnd) { throw "Supported C: growth overlaps another partition. $diagnostics" }
    $blockedBytes += $entry.Offset - $cursor
    $cursor = $entry.Offset + $entry.Size
}
$blockedBytes += $disk.Size - $cursor
if ($blockedBytes -ge $tolerance) {
    throw "C: cannot consume $blockedBytes bytes of unused OS disk capacity. Recovery/other partitions require separately approved remediation; no partitions were changed. $diagnostics"
}
$originalPartitionSize = $partition.Size
$originalVolumeSize = $volume.Size
$minimumFinalSize = $originalPartitionSize
if ($targetSize -ge ($partition.Size + $tolerance)) {
    Resize-Partition -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -Size $targetSize
    $minimumFinalSize = $targetSize
} else {
    Write-Output 'Skipping C: resize: less than 1 MiB of aligned growth is available.'
}
$verifiedDisks = @(Get-Disk -Number $disk.Number)
$verifiedPartitions = @(Get-Partition -DriveLetter C)
if ($verifiedDisks.Count -ne 1 -or $verifiedPartitions.Count -ne 1) {
    throw "OS disk or C: partition disappeared during verification. $diagnostics"
}
$verifiedDisk = $verifiedDisks[0]
$verifiedPartition = $verifiedPartitions[0]
if ($verifiedDisk.UniqueId -ne $disk.UniqueId -or $verifiedDisk.Size -lt $disk.Size -or
    -not $verifiedDisk.IsBoot -or $verifiedDisk.IsOffline -or $verifiedDisk.IsReadOnly -or
    $verifiedDisk.HealthStatus -ne 'Healthy' -or
    $verifiedPartition.DiskNumber -ne $disk.Number -or $verifiedPartition.PartitionNumber -ne $partition.PartitionNumber -or
    $verifiedPartition.Offset -ne $partition.Offset -or -not $verifiedPartition.IsBoot -or
    $verifiedPartition.Size -lt $minimumFinalSize) {
    throw "C: partition expansion verification failed or disk identity changed. $diagnostics"
}
$verifiedVolumes = @($verifiedPartition | Get-Volume)
if ($verifiedVolumes.Count -ne 1 -or $verifiedVolumes[0].UniqueId -ne $volume.UniqueId -or
    $verifiedVolumes[0].FileSystemType -ne 'NTFS' -or $verifiedVolumes[0].HealthStatus -ne 'Healthy' -or
    $verifiedVolumes[0].DriveLetter -ne 'C' -or
    $verifiedVolumes[0].Size -lt ($verifiedPartition.Size - $tolerance) -or
    $verifiedVolumes[0].Size -gt $verifiedPartition.Size -or
    $verifiedVolumes[0].Size -lt $originalVolumeSize) {
    throw "C: NTFS volume expansion verification failed. $diagnostics"
}
Write-Output "Verified C: partition $originalPartitionSize -> $($verifiedPartition.Size) bytes; NTFS $originalVolumeSize -> $($verifiedVolumes[0].Size) bytes. No other partitions, ACLs, or services were changed."
