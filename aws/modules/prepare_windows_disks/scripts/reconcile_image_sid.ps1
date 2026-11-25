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

# Initializes the ArcGIS descriptor API if it hasn't been loaded already.
function Initialize-ArcGISDescriptorApi {
    if ('ArcGISFileSecurity' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

public static class ArcGISFileSecurity {
    [StructLayout(LayoutKind.Sequential)]
    public struct FileInfo {
        public uint Attributes, CreationLow, CreationHigh, AccessLow, AccessHigh, WriteLow, WriteHigh,
            Volume, SizeHigh, SizeLow, Links, IdHigh, IdLow;
    }
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    private struct Privilege { public uint Count; public long Luid; public uint Attributes; }
    [DllImport("kernel32.dll")] private static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out SafeFileHandle token);
    [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool LookupPrivilegeValue(string system, string name, out long luid);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(SafeFileHandle token, bool disable, ref Privilege state,
        uint size, IntPtr previous, IntPtr returned);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sa,
        uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInfo info);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFinalPathNameByHandle(SafeFileHandle handle, StringBuilder path, uint size, uint flags);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetKernelObjectSecurity(SafeFileHandle handle, uint flags, byte[] descriptor,
        uint size, out uint required);
    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool SetKernelObjectSecurity(SafeFileHandle handle, uint flags, byte[] descriptor);

    public static void EnablePrivilege(string name) {
        SafeFileHandle token;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) throw new Win32Exception();
        using (token) {
            long luid;
            if (!LookupPrivilegeValue(null, name, out luid)) throw new Win32Exception();
            var p = new Privilege { Count = 1, Luid = luid, Attributes = 2 };
            if (!AdjustTokenPrivileges(token, false, ref p, 0, IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception();
            int error = Marshal.GetLastWin32Error();
            if (error != 0) throw new Win32Exception(error, "Cannot enable " + name);
        }
    }
    public static SafeFileHandle Open(string path, uint writeFlags) {
        uint access = 0x20080; // READ_CONTROL and FILE_READ_ATTRIBUTES
        if ((writeFlags & 1) != 0) access |= 0x80000;
        if ((writeFlags & 4) != 0) access |= 0x40000;
        var handle = CreateFile(path, access, 3, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
        if (!handle.IsInvalid) return handle;
        int error = Marshal.GetLastWin32Error();
        handle.Dispose();
        throw new Win32Exception(error, path + ": " + new Win32Exception(error).Message);
    }
    public static FileInfo Identity(SafeFileHandle handle) {
        FileInfo info;
        if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception();
        return info;
    }
    public static string Path(SafeFileHandle handle) {
        var path = new StringBuilder(32768);
        uint length = GetFinalPathNameByHandle(handle, path, (uint)path.Capacity, 9); // opened name, volume GUID
        if (length == 0 || length >= path.Capacity) throw new Win32Exception();
        return path.ToString();
    }
    public static byte[] Read(SafeFileHandle handle) {
        uint size;
        GetKernelObjectSecurity(handle, 7, null, 0, out size);
        if (size == 0) throw new Win32Exception();
        var data = new byte[size];
        if (!GetKernelObjectSecurity(handle, 7, data, size, out size)) throw new Win32Exception();
        return data;
    }
    public static void Write(SafeFileHandle handle, uint flags, byte[] data) {
        // Unlike SetSecurityInfo, this low-level write does not propagate inheritable ACEs.
        // NTFS derives AUTO_INHERITED from AUTO_INHERIT_REQ on a DACL write.
        if ((flags & 4) != 0 && (data[3] & 4) != 0) {
            data = (byte[])data.Clone();
            data[3] |= 1;
        }
        if (!SetKernelObjectSecurity(handle, flags, data)) throw new Win32Exception();
    }
}
'@
}

# Retrieves the open identity of a file, ensuring it resides within the verified data volume.
#
# Parameters:
#   -Handle: The open file handle.
#   -Path: The expected path of the file relative to the root.
#   -Root: The root of the verified data volume.
function Get-ArcGISOpenIdentity($Handle, [string]$Path, [string]$Root) {
    if ([ArcGISFileSecurity]::Path($Handle).TrimEnd('\') -ne ($Root.TrimEnd('\') + $Path.Substring(2)).TrimEnd('\')) {
        throw "Path '$Path' escaped the verified data volume or was redirected."
    }
    $info = [ArcGISFileSecurity]::Identity($Handle)
    [pscustomobject]@{
        Id = "$($info.Volume):$($info.IdHigh):$($info.IdLow)"
        Directory = ($info.Attributes -band 16) -ne 0
        Reparse = ($info.Attributes -band 1024) -ne 0
        Links = $info.Links
    }
}

function Get-ArcGISDescriptorBytes($Descriptor) {
    $data = [byte[]]::new($Descriptor.BinaryLength)
    $Descriptor.GetBinaryForm($data, 0)
    [Convert]::ToBase64String($data)
}

# Tests whether two ArcGIS security descriptors match, considering potential NTFS modifications.
#
# Parameters:
#   -Actual: The actual security descriptor in base64 format.
#   -Expected: The expected security descriptor in base64 format.
#   -WriteFlags: Flags indicating how the descriptor was written.
#   -AllowDuplicateRemoval: If specified, allows for NTFS to have removed duplicate ACEs.
function Test-ArcGISDescriptorMatch([string]$Actual, [string]$Expected, [uint32]$WriteFlags, [switch]$AllowDuplicateRemoval) {
    if ($Actual -ceq $Expected) { return $true }
    if (($WriteFlags -band 4) -eq 0) { return $false }

    $read = [Security.AccessControl.RawSecurityDescriptor]::new([Convert]::FromBase64String($Actual), 0)
    $saved = [Security.AccessControl.RawSecurityDescriptor]::new([Convert]::FromBase64String($Expected), 0)
    # NTFS may clear these two flags when setting the DACL.
    $clearable = [Security.AccessControl.ControlFlags]'DiscretionaryAclDefaulted, DiscretionaryAclAutoInheritRequired'
    $saved.SetFlags($saved.ControlFlags -band ($read.ControlFlags -bor (-bnot [int]$clearable)))
    if ($AllowDuplicateRemoval -and $null -ne $saved.DiscretionaryAcl -and $null -ne $read.DiscretionaryAcl -and
        $read.DiscretionaryAcl.Count -lt $saved.DiscretionaryAcl.Count) {
        # NTFS can drop a later byte-identical Allow ACE. Require every other
        # ACE to match in order, and keep the first instance of each Allow ACE.
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $acl = [Security.AccessControl.RawAcl]::new($saved.DiscretionaryAcl.Revision, $read.DiscretionaryAcl.Count)
        foreach ($ace in $saved.DiscretionaryAcl) {
            $bytes = Get-ArcGISDescriptorBytes $ace
            if ($acl.Count -lt $read.DiscretionaryAcl.Count -and
                $bytes -ceq (Get-ArcGISDescriptorBytes $read.DiscretionaryAcl[$acl.Count])) {
                $acl.InsertAce($acl.Count, $ace)
                if ($ace.AceType -eq [Security.AccessControl.AceType]::AccessAllowed) { $null = $seen.Add($bytes) }
            } elseif (-not $seen.Contains($bytes)) {
                return $false
            }
        }
        $saved.DiscretionaryAcl = $acl
    }
    return $Actual -ceq (Get-ArcGISDescriptorBytes $saved)
}

# Computes the differences between two ArcGIS security descriptors.
#
# Parameters:
#   -Actual: The actual security descriptor in base64 format.
#   -Expected: The expected security descriptor in base64 format.
function Get-ArcGISDescriptorDifference([string]$Actual, [string]$Expected) {
    $read = [Security.AccessControl.RawSecurityDescriptor]::new([Convert]::FromBase64String($Actual), 0)
    $saved = [Security.AccessControl.RawSecurityDescriptor]::new([Convert]::FromBase64String($Expected), 0)
    $differences = @()
    if ($read.Owner -ne $saved.Owner) { $differences += 'owner' }
    if ($read.Group -ne $saved.Group) { $differences += 'group' }
    if ($read.ControlFlags -ne $saved.ControlFlags) {
        $differences += 'control flags (expected 0x{0:X4}, observed 0x{1:X4})' -f [int]$saved.ControlFlags, [int]$read.ControlFlags
    }
    foreach ($section in 'DiscretionaryAcl', 'SystemAcl') {
        $actualAcl = $read.$section
        $expectedAcl = $saved.$section
        if ($null -eq $actualAcl -or $null -eq $expectedAcl) {
            if (($null -eq $actualAcl) -ne ($null -eq $expectedAcl)) { $differences += "$section presence" }
        } elseif ((Get-ArcGISDescriptorBytes $actualAcl) -cne (Get-ArcGISDescriptorBytes $expectedAcl)) {
            $differences += "$section bytes (expected $($expectedAcl.Count) ACEs, observed $($actualAcl.Count))"
        }
    }
    if (-not $differences.Count) { return 'other descriptor bytes' }
    return ($differences -join ', ')
}

# Determines the necessary changes to reconcile the security descriptors of files under a given root.
#
# Parameters:
#   -Root: The root directory to start scanning from.
#   -Source: The source SID to replace.
#   -Target: The target SID to replace with.
function Get-ArcGISDiskChanges([string]$Root, $Source, $Target) {
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push('D:\')
    while ($pending.Count) {
        $path = $pending.Pop()
        $handle = [ArcGISFileSecurity]::Open($path, 0)
        try {
            $file = Get-ArcGISOpenIdentity $handle $path $Root
            $before = [Security.AccessControl.RawSecurityDescriptor]::new([ArcGISFileSecurity]::Read($handle), 0)
            # Write inherited copies in place without propagation so unrelated children and ACL ordering stay intact.
            $after = Convert-ArcGISSecurityDescriptorSid $before $Source $Target -IncludeInherited
            $original = Get-ArcGISDescriptorBytes $before
            $desired = Get-ArcGISDescriptorBytes $after
            if ($original -cne $desired) {
                if (-not $file.Directory -and $file.Links -ne 1) {
                    throw "Changing a multiply linked file is unsupported: '$path'."
                }
                $flags = if ($before.Owner -eq $Source) { 1 } else { 0 }
                if ($null -ne $before.DiscretionaryAcl -and @($before.DiscretionaryAcl | Where-Object {
                    $_.SecurityIdentifier -eq $Source
                }).Count) { $flags = $flags -bor 4 }
                $probe = [ArcGISFileSecurity]::Open($path, $flags)
                try { $null = Get-ArcGISOpenIdentity $probe $path $Root } finally { $probe.Dispose() }
                [pscustomobject]@{ path = $path; id = $file.Id; flags = $flags; before = $original; after = $desired }
            }
            if ($file.Directory -and -not $file.Reparse) {
                foreach ($child in Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop) { $pending.Push($child.FullName) }
            }
        } catch { throw "Cannot inspect '$path': $_" }
        finally { $handle.Dispose() }
    }
}

# Applies the determined security descriptor changes to the files.
#
# Parameters:
#   -Changes: The list of changes to apply.
#   -Root: The root directory of the verified data volume.
#   -Restore: If specified, restores the original descriptors instead of applying the replacements.
function Set-ArcGISDiskDescriptors($Changes, [string]$Root, [switch]$Restore) {
    foreach ($change in $Changes) {
        $handle = [ArcGISFileSecurity]::Open($change.path, $change.flags)
        try {
            $file = Get-ArcGISOpenIdentity $handle $change.path $Root
            if ($file.Id -ne $change.id -or (-not $file.Directory -and $file.Links -ne 1)) {
                throw 'File identity or link count changed.'
            }
            $current = Get-ArcGISDescriptorBytes ([Security.AccessControl.RawSecurityDescriptor]::new([ArcGISFileSecurity]::Read($handle), 0))
            $expected = if ($Restore) { $change.after } else { $change.before }
            $desired = if ($Restore) { $change.before } else { $change.after }
            if (Test-ArcGISDescriptorMatch $current $desired $change.flags -AllowDuplicateRemoval:(-not $Restore)) { continue }
            if (-not (Test-ArcGISDescriptorMatch $current $expected $change.flags -AllowDuplicateRemoval:$Restore)) {
                $fromOriginal = Get-ArcGISDescriptorDifference $current $change.before
                $fromReplacement = Get-ArcGISDescriptorDifference $current $change.after
                throw "Descriptor differs from the saved original and replacement. Write flags: $($change.flags). Original differences: $fromOriginal. Replacement differences: $fromReplacement."
            }
            [ArcGISFileSecurity]::Write($handle, $change.flags, [Convert]::FromBase64String($desired))
            $written = Get-ArcGISDescriptorBytes ([Security.AccessControl.RawSecurityDescriptor]::new([ArcGISFileSecurity]::Read($handle), 0))
            if (-not (Test-ArcGISDescriptorMatch $written $desired $change.flags -AllowDuplicateRemoval:(-not $Restore))) {
                $expectedFlags = [Security.AccessControl.RawSecurityDescriptor]::new([Convert]::FromBase64String($desired), 0).ControlFlags
                $actualFlags = [Security.AccessControl.RawSecurityDescriptor]::new([Convert]::FromBase64String($written), 0).ControlFlags
                throw "Windows did not retain the expected descriptor (expected flags: $expectedFlags; observed flags: $actualFlags)."
            }
        } catch { throw "Cannot reconcile '$($change.path)': $_" }
        finally { $handle.Dispose() }
    }
}

# Reconciles the SIDs of an ArcGIS image, ensuring that the security descriptors match the expected state.
#
# Parameters:
#   -Role: The role of the image ('application' or 'fileserver').
#   -DeploymentDisk: The deployment disk identifier.
#   -Machine: The machine identity.
#   -Partition: The partition GUID.
#   -VolumePath: The path to the volume.
#   -Restore: If specified, restores the original descriptors instead of applying replacements.
#   -VerifyOnly: If specified, only verifies the descriptors without making changes.
#   -AllowDataDiskRebind: If specified, allows an approved recovery to replace an application disk binding.
#   -ExpectedAccount: The expected service account for the image.
function Invoke-ArcGISImageSidReconciliation {
    param(
        [ValidateSet('application', 'fileserver')][string]$Role,
        [string]$DeploymentDisk,
        [string]$Machine,
        [guid]$Partition,
        [string]$VolumePath,
        [switch]$Restore,
        [switch]$VerifyOnly,
        [switch]$AllowDataDiskRebind,
        [string]$ExpectedAccount
    )
    $paths = Get-ArcGISIdentityPaths
    $raw = Get-ArcGISImageRecord $paths.os
    $record = ConvertFrom-Json -InputObject $raw
    if ($record.schema -ne 1 -or $record.role -ne $Role -or
        $record.kind -notin @('local', 'nonlocal', 'none') -or
        $record.partition -ne $Partition.ToString('D') -or $Partition -eq [guid]::Empty -or
        [guid]$record.lineage -eq [guid]::Empty -or
        $raw -cne (Get-ArcGISImageRecord $paths.data)) {
        throw 'Image identity or data disk lineage does not match. Refusing to change ACLs.'
    }
    if (-not $DeploymentDisk -or -not $Machine) { throw 'Missing deployment disk or VM identity.' }
    $binding = @{ lineage = $record.lineage; machine = $Machine; disk = $DeploymentDisk; source = ''; target = '' }
    if ($record.kind -eq 'none') {
        if ($Role -ne 'fileserver' -or $record.account -or $record.sid) { throw 'Invalid no-account image identity.' }
    } else {
        $current = Get-ArcGISAccountIdentity $record.account
        if ($current.kind -ne $record.kind) { throw 'The service account identity type changed.' }
        if ($ExpectedAccount -and (Get-ArcGISAccountIdentity $ExpectedAccount).sid -ne $current.sid) {
            throw 'The configured service account does not match the account recorded in the image.'
        }
        $source = [Security.Principal.SecurityIdentifier]::new($record.sid)
        $target = [Security.Principal.SecurityIdentifier]::new($current.sid)
        if ($record.kind -eq 'nonlocal' -and $source -ne $target) { throw 'The nonlocal service account SID changed.' }
        if ($source -ne $target -and (-not $source.IsAccountSid() -or -not $target.IsAccountSid() -or
            $source.AccountDomainSid -eq $target.AccountDomainSid)) {
            throw 'Expected distinct source and target local machine identities.'
        }
        $binding.source = $source.Value
        $binding.target = $target.Value
    }
    $bindingPath = Join-Path $paths.data 'deployment.json'
    $journalPath = Join-Path $paths.os 'descriptor-backup.json'
    $successPath = Join-Path $paths.data 'verified.json'
    $lock = [Threading.Mutex]::new($false, 'Global\ArcGISImageSidReconciliation')
    $held = $false
    try {
        try { $held = $lock.WaitOne(0) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'Another SID reconciliation is running.' }
        if (Test-Path -LiteralPath $bindingPath) {
            Assert-ArcGISIdentityPath $bindingPath
            $previous = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
            $bindingMismatch = $false
            foreach ($key in $binding.Keys) {
                if ($previous.$key -cne $binding[$key]) {
                    $bindingMismatch = $true
                }
            }
            if ($bindingMismatch -and $AllowDataDiskRebind -and $Role -eq 'application') {
                foreach ($path in @($bindingPath, $journalPath, $successPath)) {
                    if (Test-Path -LiteralPath $path) {
                        Assert-ArcGISIdentityPath $path
                        Remove-Item -LiteralPath $path -Force
                    }
                }
                Write-ArcGISIdentityFile $bindingPath ($binding | ConvertTo-Json -Compress)
            } elseif ($bindingMismatch -and $record.kind -ne 'none') {
                    throw 'This data disk was prepared for a different VM, disk attachment, or account. Use an approved recovery.'
            }
        } else {
            if ($VerifyOnly -or $Restore -or (Test-Path -LiteralPath $journalPath) -or (Test-Path -LiteralPath $successPath)) {
                throw 'The deployment binding is missing. Complete infrastructure disk preparation before configuring ArcGIS.'
            }
            Write-ArcGISIdentityFile $bindingPath ($binding | ConvertTo-Json -Compress)
        }
        if ($record.kind -eq 'none' -or $source -eq $target) {
            if ($Restore) { throw 'No SID was replaced on this disk.' }
            Write-Output "No SID replacement needed for '$($record.kind)' image identity."
            return
        }
        if ($VerifyOnly) {
            Assert-ArcGISIdentityPath $successPath
            if ((Get-Content -LiteralPath $successPath -Raw) -cne $target.Value) { throw 'Unexpected verification marker.' }
            return
        }
        Initialize-ArcGISDescriptorApi
        [ArcGISFileSecurity]::EnablePrivilege('SeBackupPrivilege')
        [ArcGISFileSecurity]::EnablePrivilege('SeRestorePrivilege')
        $rootHandle = [ArcGISFileSecurity]::Open('D:\', 0)
        try {
            $root = [ArcGISFileSecurity]::Path($rootHandle)
            if ($root.TrimEnd('\') -ne $VolumePath.TrimEnd('\')) { throw 'D: no longer maps to the verified volume.' }
            if (Test-Path -LiteralPath $journalPath) {
                Assert-ArcGISIdentityPath $journalPath
                $backup = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
                foreach ($key in $binding.Keys) {
                    if ($backup.binding.$key -cne $binding[$key]) { throw 'Descriptor backup does not match the deployment binding.' }
                }
                $changes = @($backup.changes)
            } else {
                if ($Restore) { throw 'No saved descriptors to restore.' }
                $changes = @(Get-ArcGISDiskChanges $root $source $target)
                if ($changes.Count) {
                    Write-ArcGISIdentityFile $journalPath (@{ binding = $binding; changes = $changes } | ConvertTo-Json -Depth 6 -Compress)
                }
            }
            if ($Restore) {
                Set-ArcGISDiskDescriptors $changes $root -Restore
                if (Test-Path -LiteralPath $successPath) { Remove-Item -LiteralPath $successPath }
                Write-Output 'Restored the original owner and DACL for the saved descriptors.'
                return
            }
            if (Test-Path -LiteralPath $successPath) {
                Assert-ArcGISIdentityPath $successPath
                if ((Get-Content -LiteralPath $successPath -Raw) -cne $target.Value) { throw 'Unexpected verification marker.' }
            } else {
                Set-ArcGISDiskDescriptors $changes $root
            }
            $left = @(Get-ArcGISDiskChanges $root $source $target)
            if ($left.Count) { throw "The source SID remains on '$($left[0].path)'. Use the saved backup for recovery." }
            if (-not (Test-Path -LiteralPath $successPath)) { Write-ArcGISIdentityFile $successPath $target.Value }
            Write-Output "Verified SID reconciliation for $($record.lineage): $($changes.Count) saved descriptors."
        } finally { $rootHandle.Dispose() }
    } finally {
        if ($held) { $lock.ReleaseMutex() }
        $lock.Dispose()
    }
}
