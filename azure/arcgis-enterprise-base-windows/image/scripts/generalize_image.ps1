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

# Runs Sysprep before Packer captures the application or file-server image.
# Collects diagnostics and blocks capture unless Windows is ready to be captured.

$ErrorActionPreference = 'Stop'
$imageStatePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State'

function Write-ImageDiagnostics {
    param([string]$Phase)

    Write-Output "=== Image diagnostics: $Phase ==="
    Get-Disk |
        Select-Object Number, Location, Guid, PartitionStyle, IsBoot, IsSystem, IsOffline, IsReadOnly |
        Format-Table -AutoSize | Out-String | Write-Output
    Get-Partition |
        Select-Object DiskNumber, PartitionNumber, DriveLetter, Type, Size |
        Format-Table -AutoSize | Out-String | Write-Output
    Get-Volume |
        Select-Object DriveLetter, DriveType, FileSystemType, HealthStatus, Size |
        Format-Table -AutoSize | Out-String | Write-Output
    Get-CimInstance -ClassName Win32_CDROMDrive |
        Select-Object Drive, MediaLoaded, Status, ConfigManagerErrorCode |
        Format-Table -AutoSize | Out-String | Write-Output
    Get-Service -Name RdAgent, WindowsAzureGuestAgent |
        Select-Object Name, Status, StartType |
        Format-Table -AutoSize | Out-String | Write-Output

    foreach ($path in @(
        $imageStatePath,
        'HKLM:\SYSTEM\Setup',
        'HKLM:\SYSTEM\Setup\Status\SysprepStatus',
        'HKLM:\SYSTEM\CurrentControlSet\Services\cdrom'
    )) {
        Write-Output "Registry state: $path"
        if (Test-Path -LiteralPath $path) {
            Get-ItemProperty -LiteralPath $path |
                Select-Object ImageState, SystemSetupInProgress, OOBEInProgress, SetupPhase,
                    GeneralizationState, CleanupState, Start |
                Format-List | Out-String | Write-Output
        } else {
            Write-Output 'Registry key is not present.'
        }
    }

    foreach ($path in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )) {
        Write-Output "Pending reboot marker: $path = $(Test-Path -LiteralPath $path)"
    }
    $sessionManager = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    Write-Output "Pending file renames: $(@($sessionManager.PendingFileRenameOperations).Count)"

    foreach ($path in @(
        "$env:SystemRoot\System32\Sysprep\Panther\setupact.log",
        "$env:SystemRoot\System32\Sysprep\Panther\setuperr.log",
        "$env:SystemRoot\Panther\setupact.log",
        "$env:SystemRoot\Panther\setuperr.log",
        'C:\WindowsAzure\Logs\WaAppAgent.log'
    )) {
        if (Test-Path -LiteralPath $path) {
            $log = Get-Item -LiteralPath $path
            Write-Output "Log: $path; bytes=$($log.Length); modified=$($log.LastWriteTimeUtc.ToString('o'))"
            if ($log.Name -eq 'setuperr.log') {
                $errors = @(Get-Content -LiteralPath $path)
                $codes = @([regex]::Matches(($errors -join "`n"), '(?i)\b0x[0-9a-f]{8}\b') |
                    ForEach-Object Value | Select-Object -Unique)
                Write-Output "Setup error log lines: $($errors.Count); error codes: $($codes -join ', ')"
            }
        } else {
            Write-Output "Log not present: $path"
        }
    }
}

Write-ImageDiagnostics -Phase 'before Sysprep'
Write-Output 'Starting Sysprep with a 15-minute timeout.'
$process = Start-Process -FilePath "$env:SystemRoot\System32\Sysprep\Sysprep.exe" `
    -ArgumentList '/oobe', '/generalize', '/quiet', '/quit', '/mode:vm' -PassThru
$timer = [Diagnostics.Stopwatch]::StartNew()
while (-not $process.HasExited -and $timer.Elapsed.TotalMinutes -lt 15) {
    Start-Sleep -Seconds 5
    $process.Refresh()
}
$timer.Stop()

Write-ImageDiagnostics -Phase 'after Sysprep'
if (-not $process.HasExited) {
    throw 'Sysprep did not exit within 15 minutes. Image publication is prohibited; inspect the reported guest logs.'
}
Write-Output "Sysprep exit code: $($process.ExitCode); elapsed seconds: $([int]$timer.Elapsed.TotalSeconds)"
if ($process.ExitCode -ne 0) {
    throw "Sysprep failed with exit code $($process.ExitCode). Image publication is prohibited."
}
$imageState = (Get-ItemProperty -LiteralPath $imageStatePath -Name ImageState).ImageState
if ($imageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
    throw "Unexpected Windows ImageState '$imageState'. Image publication requires IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE."
}
Write-Output 'Sysprep completed and Windows image state is ready for capture.'
