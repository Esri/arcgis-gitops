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

# Retrieves the identity information for a given ArcGIS account.
#
# Parameters:
#   -Name: The name of the account (either local or DOMAIN\user).
function Get-ArcGISAccountIdentity([string]$Name) {
    if ($Name -notmatch '^(?:(?<authority>[^\\@]+)\\)?(?<user>[^\\@]+)$' -or $Name.Trim() -ne $Name) {
        throw 'Expected an unqualified local account or a qualified Windows account (DOMAIN\user).'
    }
    $authority = $Matches['authority']
    $user = $Matches['user']
    if (-not $authority -or $authority -in @('.', $env:COMPUTERNAME)) {
        $local = @(Get-LocalUser -Name $user -ErrorAction Stop | Where-Object { $_.Name -eq $user })
        if ($local.Count -ne 1 -or $local[0].PrincipalSource -ne 'Local') {
            throw "Expected one local Windows account named '$user'."
        }
        return @{ kind = 'local'; account = $local[0].Name; sid = $local[0].SID.Value }
    }
    $sid = ([Security.Principal.NTAccount]::new($Name)).Translate([Security.Principal.SecurityIdentifier])
    return @{ kind = 'nonlocal'; account = $Name; sid = $sid.Value }
}

# Creates a new ArcGIS identity directory with the appropriate security settings.
#
# Parameters:
#   -Path: The path to the identity directory to create.
function New-ArcGISIdentityDirectory([string]$Path) {
    Assert-ArcGISIdentityParent $Path
    if (Test-Path -LiteralPath $Path) { throw "Refusing to overwrite identity directory '$Path'." }
    $security = [Security.AccessControl.DirectorySecurity]::new()
    $security.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
    [IO.Directory]::CreateDirectory($Path, $security) | Out-Null
    Assert-ArcGISIdentityPath $Path
}

# Asserts that the parent directory of an ArcGIS identity directory is secure.
#
# Parameters:
#   -Path: The path to the identity directory.
function Assert-ArcGISIdentityParent([string]$Path) {
    $parent = Get-Item -LiteralPath (Split-Path -Parent $Path) -Force
    if ($parent.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        throw "Identity parent '$($parent.FullName)' is a reparse point."
    }
    $acl = Get-Acl -LiteralPath $parent.FullName
    $trusted = @('S-1-5-18', 'S-1-5-32-544',
        'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464') # TrustedInstaller
    $dangerous = [Security.AccessControl.FileSystemRights]'DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership'
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin $trusted) {
        throw "Identity parent '$($parent.FullName)' has untrusted owner SID '$owner'."
    }
    $unsafeRules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | Where-Object {
        $_.IdentityReference.Value -notin $trusted -and $_.AccessControlType -eq 'Allow' -and
        -not $_.PropagationFlags.HasFlag([Security.AccessControl.PropagationFlags]::InheritOnly) -and
        ($_.FileSystemRights -band $dangerous) -ne 0
    })
    if ($unsafeRules.Count) {
        $details = ($unsafeRules | ForEach-Object {
            "$($_.IdentityReference.Value): $($_.FileSystemRights -band $dangerous)"
        }) -join '; '
        throw "Identity parent '$($parent.FullName)' grants unsafe rights on the parent: $details."
    }
}

# Asserts that an ArcGIS identity directory has the expected security settings.
#
# Parameters:
#   -Path: The path to the identity directory.
function Assert-ArcGISIdentityPath([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
        throw "Identity path '$Path' is a reparse point."
    }
    $acl = Get-Acl -LiteralPath $Path
    $trusted = @('S-1-5-18', 'S-1-5-32-544')
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $trusted -or
        $rules.Count -ne 2 -or ($item.PSIsContainer -and -not $acl.AreAccessRulesProtected)) {
        throw "Identity path '$Path' has unexpected security."
    }
    foreach ($sid in $trusted) {
        if (@($rules | Where-Object {
            $_.IdentityReference.Value -eq $sid -and $_.AccessControlType -eq 'Allow' -and
            $_.FileSystemRights -eq [Security.AccessControl.FileSystemRights]::FullControl
        }).Count -ne 1) { throw "Identity path '$Path' has unexpected access rules." }
    }
}

# Retrieves the paths for the ArcGIS identity directories.
#
# Returns:
#   A hashtable with 'os' and 'data' keys pointing to the respective identity directories.
function Get-ArcGISIdentityPaths {
    # Use direct children of standard roots, not a potentially user-created ArcGIS directory.
    @{
        os = Join-Path $env:SystemRoot 'ArcGIS-ImageIdentity'
        data = 'D:\ArcGIS-ImageIdentity'
    }
}

# Retrieves the ArcGIS image record from the specified identity directory.
#
# Parameters:
#   -Directory: The path to the identity directory.
#
# Returns:
#   The contents of the 'service-account.json' file as a string.
function Get-ArcGISImageRecord([string]$Directory) {
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "Missing image identity directory '$Directory'. Rebuild the image or use an approved migration."
    }
    Assert-ArcGISIdentityParent $Directory
    Assert-ArcGISIdentityPath $Directory
    $file = Join-Path $Directory 'service-account.json'
    Assert-ArcGISIdentityPath $file
    [IO.File]::ReadAllText($file)
}

# Writes the specified text to an ArcGIS identity file, ensuring it is created securely.
#
# Parameters:
#   -Path: The path to the identity file.
#   -Text: The content to write to the file.
function Write-ArcGISIdentityFile([string]$Path, [string]$Text) {
    $stream = [IO.File]::Open($Path, 'CreateNew', 'Write', 'None')
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally { $stream.Dispose() }
    Assert-ArcGISIdentityPath $Path
}

# Retrieves the Azure VM identity for the current instance.
#
# Returns:
#   The VM ID as a string in 'D' format.
function Get-ArcGISAzureVmId {
    $client = [Net.WebClient]::new()
    try {
        $client.Proxy = $null
        $client.Headers['Metadata'] = 'true'
        $machine = [guid]$client.DownloadString('http://169.254.169.254/metadata/instance/compute/vmId?api-version=2021-02-01&format=text')
        if ($machine -eq [guid]::Empty) { throw 'Missing Azure VM identity.' }
        $machine.ToString('D')
    } finally { $client.Dispose() }
}

# Initializes the ArcGIS image identity for the current instance.
#
# Parameters:
#   -Role: The role of the image ('application' or 'fileserver').
#   -Account: The service account for the image (can be empty for no-account images).
#   -IndependentDisk: If specified, indicates that the image uses an independent disk.
function Initialize-ArcGISImageIdentity {
    param(
        [ValidateSet('application', 'fileserver')][string]$Role,
        [AllowEmptyString()][string]$Account,
        [switch]$IndependentDisk
    )
    if ($IndependentDisk -and ($Role -ne 'fileserver' -or $Account)) {
        throw 'Independent disks are supported only for file-server images without a baked service account.'
    }
    if ($Role -eq 'application' -and -not $Account) { throw 'Application images require a service account.' }
    $identity = if ($Account) { Get-ArcGISAccountIdentity $Account } else {
        @{ kind = 'none'; account = ''; sid = '' }
    }
    $paths = Get-ArcGISIdentityPaths
    $identity.schema = 1
    $identity.role = $Role
    $identity.lineage = [guid]::NewGuid().ToString('D')
    $identity.partition = if ($IndependentDisk) { '' } else {
        $partition = Get-Partition -DriveLetter D
        if (-not $partition.Guid -or [guid]$partition.Guid -eq [guid]::Empty) {
            throw 'The image data partition has no GPT identity.'
        }
        ([guid]$partition.Guid).ToString('D')
    }
    $json = $identity | ConvertTo-Json -Compress
    New-ArcGISIdentityDirectory $paths.os
    if (-not $IndependentDisk) { New-ArcGISIdentityDirectory $paths.data }
    foreach ($directory in @($paths.os) + $(if (-not $IndependentDisk) { @($paths.data) } else { @() })) {
        $file = Join-Path $directory 'service-account.json'
        [IO.File]::WriteAllText($file, $json)
        Assert-ArcGISIdentityPath $file
    }
    Write-Output "Recorded $Role image identity ($($identity.kind)); lineage $($identity.lineage)."
}
