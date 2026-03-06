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

# The script uses Azure Run Command on the deployment VMs in the specified roles
# to delete temporary files created by Chef runs, optionally uninstalling 
# the Chef client and running sysprep.

import argparse
import az_utils

from azure.mgmt.compute.models import RunCommandInputParameter

EXECUTION_TIMEOUT = 600  # seconds

windows_script = """
param (
    [string] $Directories,
    [string] $UninstallChefClient,
    [string] $Sysprep
)
$dirs = $Directories -split ","
foreach ($dir in $dirs) {
  if ($dir) {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $dir
  }
}
if ($UninstallChefClient -eq "True") {
  $tempfolderpath = (Join-Path $Env:TEMP 'esri')
  $chefClientMsi = (Join-Path $tempfolderpath 'chef-client.msi')
  if (Test-Path $chefClientMsi) {
    Start-Process -Wait -FilePath msiexec.exe -ArgumentList \"/x $chefClientMsi /qb\"
    Remove-Item -Force $chefClientMsi
  }
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $Env:USERPROFILE '.cinc')
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $Env:SystemDrive 'chef')
}
if ($Sysprep -eq "True") {
   $sysprep = Join-Path $Env:SystemRoot "System32\\Sysprep\\Sysprep.exe"
   Start-Process $sysprep -ArgumentList '/oobe /generalize /quiet /shutdown /mode:vm' -Wait
}
Write-Output "Cleanup script completed successfully."
"""

linux_script = """
#!/bin/bash

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

function uninstall_cinc() {
  if [ "$(is_debian)" == "true" ]; then
    dpkg -P cinc
  elif [ "$(is_redhat)" == "true" ]; then
    rpm -e cinc
  elif [ "$(is_suse)" == "true" ]; then
    rpm -e cinc
  else
    echo "Unknown distribution"
  fi
}

function main() { 
  IFS=',' read -ra ADDR <<< "$Directories"
  for i in "${ADDR[@]}"; do
    rm -r $i
  done
  if [ "$UninstallChefClient" == "True" ]; then
    uninstall_cinc
    rm -r ~/.cinc
    rm -r /var/chef
  fi
  exit 0
}

main "$@"
"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="az_clean_up.py",
        description="Deletes temporary files created by Chef runs on the deployment VMs in the specified roles.",
    )

    parser.add_argument('-s', dest='site_id', help='Site Id')
    parser.add_argument('-d', dest='deployment_id', help='Deployment Id')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')
    parser.add_argument('-p', dest='sysprep', action='store_true', help='Run sysprep script')
    parser.add_argument('-u', dest='uninstall_chef_client', action='store_true', help='Uninstall Chef/Cinc Client')
    parser.add_argument('-f', dest='directories', default="", help='Comma-separated list of local directories to clean up')
    parser.add_argument("-v", dest="vault_name", help="Azure Key Vault name")

    args = parser.parse_args()

    parameters = [
        RunCommandInputParameter(name="Directories", value=args.directories),
        RunCommandInputParameter(name="UninstallChefClient", value=str(args.uninstall_chef_client)),
        RunCommandInputParameter(name="Sysprep", value=str(args.sysprep))
    ]

    ret = az_utils.run_command(
        args.site_id,
        args.deployment_id,
        args.machine_roles,
        "clean_up",
        windows_script,
        linux_script,
        parameters,
        args.vault_name,
        EXECUTION_TIMEOUT
    )

    exit(0 if ret else 1)
