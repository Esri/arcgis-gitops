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
$portalService = Get-CimInstance -ClassName Win32_Service -Filter "Name='Portal for ArcGIS'"
$account = $portalService.StartName
if ([string]::IsNullOrWhiteSpace($account)) { throw 'The Portal for ArcGIS service logon account is empty or the service is missing.' }
if ($account -eq 'LocalSystem') { $account = 'NT AUTHORITY\SYSTEM' }
elseif ($account.StartsWith('.\')) { $account = "$env:COMPUTERNAME\$($account.Substring(2))" }
elseif ($account -notmatch '[\\@]') { $account = "$env:COMPUTERNAME\$account" }
$sid = ([Security.Principal.NTAccount]::new($account)).Translate([Security.Principal.SecurityIdentifier])

$partitions = @(Get-Partition -DriveLetter D)
$volumes = @(Get-Volume -DriveLetter D)
if ($partitions.Count -ne 1 -or $volumes.Count -ne 1 -or $volumes[0].FileSystemType -ne 'NTFS') {
    throw 'Expected one NTFS data partition at D: before repairing ArcGIS permissions.'
}
$disk = Get-Disk -Number $partitions[0].DiskNumber
if ($disk.IsBoot -or $disk.IsSystem -or $disk.IsOffline -or $disk.IsReadOnly) {
    throw 'D: must be an online writable non-OS data disk.'
}
$drive = Get-Item -LiteralPath 'D:\' -Force
if (-not $drive.PSIsContainer -or ($drive.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'D: must be a local directory, not a redirected path.'
}

$items = [Collections.Generic.List[object]]::new()
$pending = [Collections.Generic.Stack[string]]::new()
foreach ($path in 'D:\arcgisportal', 'D:\arcgisdatastore') {
    $root = Get-Item -LiteralPath $path -Force
    if (-not $root.PSIsContainer) { throw "Expected an existing ArcGIS data directory: $path" }
    $pending.Push($path)
}
while ($pending.Count -gt 0) {
    $path = $pending.Pop()
    $item = Get-Item -LiteralPath $path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to repair permissions through a reparse point: $path"
    }
    $items.Add($item)
    if ($item.PSIsContainer) {
        foreach ($child in Get-ChildItem -LiteralPath $path -Force) {
            $pending.Push($child.FullName)
        }
    }
}

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
    $allow = @($rules | Where-Object {
        $_.IdentityReference.Value -eq $sid.Value -and
        $_.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
        ($_.FileSystemRights -band $fullControl) -eq $fullControl -and
        ($_.InheritanceFlags -band $inheritance) -eq $inheritance -and
        $_.PropagationFlags -eq [Security.AccessControl.PropagationFlags]::None
    })
    if ($allow.Count -eq 0) { throw "Full Control grant verification failed for $account on $($item.FullName)." }
}

foreach ($name in 'Portal for ArcGIS', 'ArcGIS Data Store') {
    Restart-Service -Name $name -ErrorAction Stop
    $service = Get-Service -Name $name
    $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromMinutes(5))
}
Write-Output "Granted $account ($($sid.Value)) Full Control on $($items.Count) Portal/Data Store data entries; existing ACLs were preserved. Portal for ArcGIS and ArcGIS Data Store are running."