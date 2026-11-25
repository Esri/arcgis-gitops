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

# Runs at Packer build VM startup for both image roles to start the Azure
# guest agent services and install Azure CLI from the configured MSI URL.

param(
    [string]$AzureCliUrl = "https://azcliprod.blob.core.windows.net/msi/azure-cli-2.76.0-x64.msi"
)

Set-Service RdAgent -StartupType Automatic
Start-Service RdAgent
Set-Service WindowsAzureGuestAgent -StartupType Automatic
Start-Service WindowsAzureGuestAgent
# Write-Output "Installing Azure CLI..."
$InstallerPath = "$Env:TEMP\AzureCLI.msi"
Invoke-WebRequest -Uri $AzureCliUrl -OutFile $InstallerPath
Start-Process msiexec.exe -Wait -ArgumentList "/I $InstallerPath /quiet /norestart"
Remove-Item $InstallerPath
# $Env:Path += ";" + [System.Environment]::GetEnvironmentVariable('Path','Machine')
# az version -o table
