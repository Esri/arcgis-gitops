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

# Prepares the image data disk for ArcGIS by validating the LUN 0 disk and its D: volume, 
# ensuring it is NTFS and properly mounted.

$ErrorActionPreference = 'Stop'
$disks = @(Get-Disk | Where-Object {
    -not $_.IsBoot -and -not $_.IsSystem -and $_.Location -match '\bLUN 0\b'
})
if ($disks.Count -ne 1) { throw 'Expected exactly one non-OS Azure LUN 0 disk before image ACL preparation.' }
$disk = $disks[0]
if ([string]::IsNullOrWhiteSpace($disk.UniqueId) -or $disk.IsOffline -or $disk.IsReadOnly) {
    throw 'Image ACL preparation requires an identified online writable LUN 0 disk.'
}
$partitions = @(Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne 'Reserved' })
if ($partitions.Count -ne 1 -or $partitions[0].DriveLetter -ne 'D' -or
    $partitions[0].Type -ne 'Basic' -or $partitions[0].IsBoot -or $partitions[0].IsSystem) {
    throw 'Image ACL preparation requires one existing non-OS LUN 0 data partition mapped to D:.'
}
$drivePartitions = @(Get-Partition -DriveLetter D)
$volumes = @($partitions[0] | Get-Volume)
if ($drivePartitions.Count -ne 1 -or $drivePartitions[0].DiskNumber -ne $disk.Number -or
    $drivePartitions[0].PartitionNumber -ne $partitions[0].PartitionNumber -or
    $volumes.Count -ne 1 -or $volumes[0].FileSystemType -ne 'NTFS') {
    throw 'Image ACL preparation requires the intended NTFS data volume at D:.'
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
    throw 'Image data volume has no recognized mount-manager path.'
}
$volumeTarget = [ArcGISDrivePaths]::GetTarget($Matches[1])
$logicalD = @(Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq 'D:' })
$psDriveD = @(Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq 'D' })
if (-not $volumeTarget -or [ArcGISDrivePaths]::GetTarget('D:') -ne $volumeTarget -or
    $logicalD.Count -ne 1 -or $logicalD[0].DriveType -ne 3 -or
    ($psDriveD | Where-Object { $_.Root -ne 'D:\' -or $_.DisplayRoot })) {
    throw 'D: is ambiguous or redirected; refusing to grant image permissions.'
}
$drive = Get-Item -LiteralPath 'D:\' -Force
if (-not $drive.PSIsContainer -or ($drive.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'D: must be a local directory, not a redirected path.'
}
$portalData = Get-Item -LiteralPath 'D:\arcgisportal' -Force
if (-not $portalData.PSIsContainer -or ($portalData.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Portal setup did not initialize a local D:\arcgisportal directory. Check the Chef cookbook version.'
}

$items = [Collections.Generic.List[object]]::new()
$pending = [Collections.Generic.Stack[string]]::new()
$pending.Push('D:\')
while ($pending.Count -gt 0) {
    $path = $pending.Pop()
    $item = Get-Item -LiteralPath $path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to grant Users permissions through a reparse point: $path"
    }
    $items.Add($item)
    if ($item.PSIsContainer) {
        foreach ($child in Get-ChildItem -LiteralPath $path -Force) {
            $pending.Push($child.FullName)
        }
    }
}

$sid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-545')
$fullControl = [Security.AccessControl.FileSystemRights]::FullControl
foreach ($item in $items) {
    $inheritance = if ($item.PSIsContainer) {
        [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else {
        [Security.AccessControl.InheritanceFlags]::None
    }
    $acl = Get-Acl -LiteralPath $item.FullName
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $sid, $fullControl, $inheritance,
        [Security.AccessControl.PropagationFlags]::None,
        [Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $item.FullName -AclObject $acl
    $verified = Get-Acl -LiteralPath $item.FullName
    $rules = @($verified.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    $deny = @($rules | Where-Object {
        $_.IdentityReference.Value -in @($sid.Value, 'S-1-1-0', 'S-1-5-11') -and
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Deny -and
        ($_.FileSystemRights -band $fullControl) -ne 0
    })
    if ($deny.Count -gt 0) {
        throw "Conflicting Users, Everyone, or Authenticated Users Deny rule on $($item.FullName). Existing ACLs were not reset."
    }
    $allow = @($rules | Where-Object {
        $_.IdentityReference.Value -eq $sid.Value -and
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        ($_.FileSystemRights -band $fullControl) -eq $fullControl -and
        ($_.InheritanceFlags -band $inheritance) -eq $inheritance -and
        $_.PropagationFlags -eq [Security.AccessControl.PropagationFlags]::None
    })
    if ($allow.Count -eq 0) { throw "Users Full Control grant verification failed on $($item.FullName)." }
}

Write-Output "Granted Users ($($sid.Value)) Full Control on $($items.Count) D: entries; existing owners and other ACL entries were preserved. Portal/Data Store startup is Manual."
