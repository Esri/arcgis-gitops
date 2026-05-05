# Copyright 2025-2026 Esri
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

from azure.mgmt.compute.models import RunCommandInputParameter

# Timeouts in seconds
EXECUTION_TIMEOUT = 1800

windows_script = """
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
    if ($? -eq $false) {
        throw "Error logging in to Azure."
    }
    $tempfolderpath = (Join-Path $env:TEMP 'esri')
    if (-not (Test-Path -Path $tempfolderpath)) {
        New-Item -ItemType Directory -Path $tempfolderpath
    }
    $chefClientMsi = (Join-Path $tempfolderpath 'chef-client.msi')
    Write-Output \"Downloading Chef/Cinc client from $ChefClientUrl...\"
    az storage blob download --blob-url $ChefClientUrl --file $chefClientMsi --auth-mode login --no-progress --output none
    if ($? -eq $false) {
        throw "Error downloading Chef/Cinc client. Run enterprise-automation-chef-azure workflow to upload the client to repository blob container."
    }
    Write-Output \"Installing Chef/Cinc client...\"
    Start-Process msiexec.exe -Wait -ArgumentList \"/I $chefClientMsi /qb\"
    $chefworkspacepath = (Join-Path $env:SystemDrive 'chef')
    if (-not (Test-Path -Path $chefworkspacepath)) {
        New-Item -ItemType Directory -Path $chefworkspacepath
    }
    Remove-Item (Join-Path $env:SystemDrive 'cinc') -Recurse -ErrorAction SilentlyContinue
    $Env:Path += ";" + [System.Environment]::GetEnvironmentVariable('Path','Machine')
    chef-client -version
    Write-Output \"Configuring Chef client...\"
    $clientConfig = @"
local_mode            true
node_name             \"provision-node\"
client_key            \"C:/chef/client.pem\"
local_key_generation  true
cookbook_path         [\"C:/chef/cookbooks\"]
cookbook_sync_threads 1
no_lazy_load          true
"@
    $clientConfig | Set-Content -Path (Join-Path $chefworkspacepath 'client.rb') -Encoding UTF8
    $cookbooks = (Join-Path $tempfolderpath 'cookbooks.tar.gz')
    Write-Output \"Downloading Chef Cookbooks for ArcGIS from $ChefCookbooksUrl...\"
    az storage blob download --blob-url $ChefCookbooksUrl --file $cookbooks --auth-mode login --no-progress --output none
    if ($? -eq $false) {
        throw "Error downloading Chef Cookbooks."
    }
    Write-Output \"Extracting cookbooks from the archive...\"
    Start-Process -Wait -FilePath tar.exe -ArgumentList \"-C $chefworkspacepath -xvzf $cookbooks\"
    Remove-Item $cookbooks
    Write-Output \"Bootstrapping completed.\"
} catch {
    Write-Error $_.Exception | format-list -force
    Write-Error 'Error occurred while bootstrapping Windows instance.' -ErrorAction Stop
}
"""

linux_script = """
#!/bin/bash

set -e

function die() {
  echo "$@" >&2
  exit 1
}

function get_contents() {
  url=$1
  path=$2
  az storage blob download --blob-url $url --file $path --auth-mode login --no-progress --output none
  if [ $? -ne 0 ]; then
    die "Error downloading from $url"
  fi
}

function exec_cmd() {
  echo "Invoking $@"
  eval "$@"
  if [ $? -ne 0 ]; then
    die "Error occurred while executing command: $@"
  fi
}

function update_cookbook() {
  cookbooks_url=$ChefCookbooksUrl
  echo "Downloading Chef Cookbooks for ArcGIS from $cookbooks_url"
  get_contents $cookbooks_url "/tmp/cookbook.tar.gz"
  exec_cmd "sudo mkdir -p /var/chef"          
  echo "Extracting cookbooks from the archive..."          
  exec_cmd "sudo tar -xf /tmp/cookbook.tar.gz -C /var/chef"
  exec_cmd "sudo rm /tmp/cookbook.tar.gz"
}

function update_chefclient() {
  chef_client_url=$ChefClientUrl
  filename=$(basename $chef_client_url)
  echo "Downloading Chef/Cinc client from $chef_client_url..."
  get_contents $chef_client_url /tmp/$filename
  echo "Installing Chef/Cinc client..."
  extension="${filename##*.}"
  if [ "$extension" == "deb" ]; then
    exec_cmd "sudo dpkg -i /tmp/$filename"
  elif [ "$extension" == "rpm" ]; then         
    exec_cmd "sudo rpm -i --force /tmp/$filename"
  else
    die "Unsupported package type."
  fi
  rm /tmp/$filename
}

function is_debian() {
  grep -E -i -c 'Debian|Ubuntu' /etc/issue 2>&1 &>/dev/null
  [ $? -eq 0 ] && echo "true" || echo "false"
}

function is_redhat() {
  if [ -f "/etc/system-release" ] || [ -f "/etc/redhat-release" ]; then
    echo "true"
  else
    echo "false"
  fi
}

function is_suse() {
  if type zypper > /dev/null; then
    echo "true"
  else
    echo "false"
  fi
}

function get_dist() {
  if [ "$(is_debian)" == "true" ]; then
    echo "debian"
  elif [ "$(is_redhat)" == "true" ]; then
    echo "redhat"
  elif [ "$(is_suse)" == "true" ]; then
    echo "suse"
  else
    die "Unknown distribution"
  fi
}

function main() {
  az login --identity --client-id $ManagedIdentityClientId --output none
  if [ $? -ne 0 ]; then
    die "Error logging in to Azure."
  fi
  update_chefclient
  update_cookbook
  echo "Bootstrapping completed."
  exit 0
}

main "$@"
"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="az_bootstrap.py",
        description="Installs CINC client and ArcGIS Chef Cookbooks on VMs in a deployment with specified roles.",
    )

    parser.add_argument("-s", dest="enterprise_id", help="ArcGIS Enterprise ID")
    parser.add_argument("-d", dest="deployment_id", help="ArcGIS Enterprise deployment ID")
    parser.add_argument("-m", dest="machine_roles", help="Machine roles")
    parser.add_argument("-c", dest="chef_client_url", help="Chef client blob store URL")
    parser.add_argument("-k", dest="chef_cookbooks_url", help="Chef cookbooks blob store URL")
    parser.add_argument("-v", dest="vault_name", help="Azure Key Vault name")

    args = parser.parse_args()

    parameters = [
      RunCommandInputParameter(name="ChefClientUrl", value=args.chef_client_url),
      RunCommandInputParameter(name="ChefCookbooksUrl", value=args.chef_cookbooks_url),
      RunCommandInputParameter(name="ManagedIdentityClientId", value="secret:vm-identity-client-id")
    ]

    ret = az_utils.run_command(
        args.enterprise_id,
        args.deployment_id,
        args.machine_roles,
        "bootstrap",
        windows_script,
        linux_script,
        parameters,
        args.vault_name,
        EXECUTION_TIMEOUT,
    )

    exit(0 if ret else 1)
