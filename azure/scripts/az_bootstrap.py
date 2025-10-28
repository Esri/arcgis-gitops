# Copyright 2025 Esri
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

# The script:
# * Uses Azure Run Command to install Cinc client and Chef Cookbooks for ArcGIS
#   on deployment VMs with specified roles.
# * Waits for all the command invocations to complete. and
# * Retrieves from the blob storage and prints errors and outputs of the commands.

import argparse
import az_utils

# Timeouts in seconds
EXECUTION_TIMEOUT = 1800

script = """
param(
    [string]$ChefClientUrl,
    [string]$ChefCookbooksUrl,
    [string]$ManagedIdentityClientId
)
try {
    $Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" `
              + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Output \"Logging in to Azure using Managed Identity...\"
    az login --identity --client-id $ManagedIdentityClientId --output none
    $tempfolderpath = (Join-Path $env:TEMP 'esri')
    if (-not (Test-Path -Path $tempfolderpath)) {
        New-Item -ItemType Directory -Path $tempfolderpath
    }
    $chefClientMsi = (Join-Path $tempfolderpath 'chef-client.msi')
    Write-Output \"Downloading Chef/Cinc client from $ChefClientUrl...\"
    az storage blob download --blob-url $ChefClientUrl --file $chefClientMsi --auth-mode login --no-progress --output none
    Write-Output \"Installing Chef/Cinc client...\"
    Start-Process msiexec.exe -Wait -ArgumentList \"/I $chefClientMsi /qb\"
    $chefworkspacepath = (Join-Path $env:SystemDrive 'chef')
    if (-not (Test-Path -Path $chefworkspacepath)) {
        New-Item -ItemType Directory -Path $chefworkspacepath
    }
    Remove-Item (Join-Path $env:SystemDrive 'cinc') -Recurse -ErrorAction SilentlyContinue
    $Env:Path += ";" + [System.Environment]::GetEnvironmentVariable('Path','Machine')
    chef-client -version
    $cookbooks = (Join-Path $tempfolderpath 'cookbooks.tar.gz')
    Write-Output \"Downloading Chef Cookbooks for ArcGIS from $ChefCookbooksUrl...\"
    az storage blob download --blob-url $ChefCookbooksUrl --file $cookbooks --auth-mode login --no-progress --output none
    Write-Output \"Extracting cookbooks from the archive...\"
    Start-Process -Wait -FilePath tar.exe -ArgumentList \"-C $chefworkspacepath -xvzf $cookbooks\"
    Remove-Item $cookbooks
    Write-Output \"Bootstrapping completed.\"
} catch {
    Write-Error $_.Exception | format-list -force
    Write-Error 'Error occurred while bootstrapping Windows instance.' -ErrorAction Stop
}
"""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="az_bootstrap.py",
        description="Installs CINC client and ArcGIS Chef Cookbooks on VMs in a deployment with specified roles.",
    )

    parser.add_argument("-s", dest="site_id", help="ArcGIS Enterprise site Id")
    parser.add_argument("-d", dest="deployment_id", help="ArcGIS Enterprise deployment Id")
    parser.add_argument("-m", dest="machine_roles", help="Machine roles")
    parser.add_argument("-c", dest="chef_client_url", help="Chef client blob store URL")
    parser.add_argument("-k", dest="chef_cookbooks_url", help="Chef cookbooks blob store URL")
    parser.add_argument("-v", dest="vault_name", help="Azure Key Vault name")

    args = parser.parse_args()

    parameters = [
        {"name": "ChefClientUrl", "value": args.chef_client_url},
        {"name": "ChefCookbooksUrl", "value": args.chef_cookbooks_url},
        {"name": "ManagedIdentityClientId", "value": "secret:vm-identity-client-id"},
    ]

    ret = az_utils.run_command(
        args.site_id,
        args.deployment_id,
        args.machine_roles,
        "bootstrap",
        script,
        parameters,
        args.vault_name,
        EXECUTION_TIMEOUT,
    )

    exit(0 if ret else 1)
