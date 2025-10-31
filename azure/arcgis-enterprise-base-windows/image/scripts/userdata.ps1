param(
    [string]$AzureCliUrl = "https://azcliprod.blob.core.windows.net/msi/azure-cli-2.76.0-x64.msi"
)

# Ensure Guest Agent and Azure CLI are up and running.
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
