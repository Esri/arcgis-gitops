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

# Verifies that D: is already the intended writable NTFS volume.
# Creates D:\data, grants built-in Users inherited Full Control there, 
# and records the original service-account SID and disk identity. 
# A standard file-server image records that it has no baked-in account.
# It does not format, resize, or remount the disk.

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^vol-[0-9a-f]+$')]
    [string]$VolumeId,
    [Parameter(Mandatory = $true)]
    [ValidateSet('application', 'fileserver')]
    [string]$ImageRole,
    [string]$EncodedAccount
)

$ErrorActionPreference = 'Stop'
$disks = @(Get-Disk | Where-Object {
    $serial = ([string]$_.SerialNumber).Trim() -replace '_[0-9]+[.]?$', '' -replace '[^A-Za-z0-9]', ''
    $serial -eq ($VolumeId -replace '-', '')
})
if ($disks.Count -ne 1) { throw "Expected exactly one image disk matching EBS volume $VolumeId." }
$disk = $disks[0]
if ($disk.IsBoot -or $disk.IsSystem -or $disk.IsOffline -or $disk.IsReadOnly -or
    $disk.HealthStatus -ne 'Healthy' -or $disk.PartitionStyle -ne 'GPT' -or
    [string]::IsNullOrWhiteSpace($disk.UniqueId)) {
    throw 'Image ACL preparation requires an identified healthy online writable non-OS GPT disk.'
}
$partitions = @(Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne 'Reserved' })
if ($partitions.Count -ne 1 -or $partitions[0].DriveLetter -ne 'D' -or
    $partitions[0].Type -ne 'Basic' -or $partitions[0].IsBoot -or $partitions[0].IsSystem) {
    throw 'Image ACL preparation requires one existing non-OS data partition mapped to D:.'
}
$drivePartitions = @(Get-Partition -DriveLetter D)
$volumes = @($partitions[0] | Get-Volume)
if ($drivePartitions.Count -ne 1 -or $drivePartitions[0].DiskNumber -ne $disk.Number -or
    $drivePartitions[0].PartitionNumber -ne $partitions[0].PartitionNumber -or
    $volumes.Count -ne 1 -or $volumes[0].FileSystemType -ne 'NTFS' -or
    $volumes[0].HealthStatus -ne 'Healthy') {
    throw 'Image ACL preparation requires the intended healthy NTFS data volume at D:.'
}
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
if ($volumes[0].Path -notmatch '^\\\\\?\\(Volume\{[^}]+\})\\$') {
    throw 'Image volume has no recognized mount-manager path.'
}
$volumeTarget = [ArcGISDrivePaths]::GetTarget($Matches[1])
$logicalD = @(Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq 'D:' })
$psDriveD = @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq 'D' })
if (-not $volumeTarget -or [ArcGISDrivePaths]::GetTarget('D:') -ne $volumeTarget -or
    $logicalD.Count -ne 1 -or $logicalD[0].DriveType -ne 3 -or
    ($psDriveD | Where-Object { $_.Root -ne 'D:\' -or $_.DisplayRoot })) {
    throw 'D: is ambiguous or redirected; refusing to grant image permissions.'
}

$root = Get-Item -LiteralPath 'D:\' -Force
if ($root.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    throw 'D:\ is a reparse point; refusing to change image permissions.'
}
$rootAcl = Get-Acl -LiteralPath $root.FullName
$ownerType = [Security.Principal.SecurityIdentifier]
if ($rootAcl.GetOwner($ownerType).Value -eq 'S-1-5-20') {
    # Network Service must not own the parent of the protected identity directory.
    $administrators = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $rootAcl.SetOwner($administrators)
    Set-Acl -LiteralPath $root.FullName -AclObject $rootAcl
    if ((Get-Acl -LiteralPath $root.FullName).GetOwner($ownerType) -ne $administrators) {
        throw 'D:\ root ownership did not change to built-in Administrators.'
    }
    Write-Output 'Changed D:\ root owner from Network Service to built-in Administrators.'
}
Assert-ArcGISIdentityParent (Get-ArcGISIdentityPaths).data

$sid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
$fullControl = [Security.AccessControl.FileSystemRights]::FullControl
$inheritance = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
$rule = [Security.AccessControl.FileSystemAccessRule]::new(
    $sid, $fullControl, $inheritance,
    [Security.AccessControl.PropagationFlags]::None,
    [Security.AccessControl.AccessControlType]::Allow)

function Grant-ArcGISFullControl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force
    if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "$Path must be a local directory, not a reparse path."
    }
    $acl = Get-Acl -LiteralPath $item.FullName
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $item.FullName -AclObject $acl
}

# Create the shared data directory before image finalization. This is required
# by file-server builds, and application builds already use descendants of it.
$dataItem = New-Item -ItemType Directory -Path 'D:\data' -Force
Grant-ArcGISFullControl -Path $dataItem.FullName

Write-Output "Created D:\data and granted Users ($($sid.Value)) Full Control with inheritance to descendants; existing owners and other ACL entries were preserved."
Initialize-ArcGISImageIdentity -Role $ImageRole -Account ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncodedAccount)))
