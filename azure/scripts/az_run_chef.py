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

# The script uses Azure Run Command to run Chef Client in solo mode on VMs in specified roles.
# It retrieves the Chef JSON attributes from the JSON_ATTRIBUTES environment variable
# and puts them into a key vault secret specified by json_attributes_secret command line argument.

import argparse
import base64
import os
import az_utils
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient


script = """
param(
    [string]$VaultName,
    [string]$JsonAttributesSecret,
    [string]$ManagedIdentityClientId,
    [string]$LogLevel = "info"
)
$Env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" `
            + [System.Environment]::GetEnvironmentVariable("Path","User")
Write-Output \"Logging in to Azure using Managed Identity...\"
az login --identity --client-id $ManagedIdentityClientId --output none
Set-Location -Path 'C:\\chef'
if (! $?) { exit 1 }
& az keyvault secret show --name $JsonAttributesSecret --vault-name $VaultName --query "value" --output tsv | Out-File attributes.json -Encoding ASCII
if (! $?) { exit 1 }
& cinc-client.bat -z -j attributes.json -l $LogLevel | Tee-Object -FilePath chef-run.log -Append
$ret = $?
Remove-Item (Join-Path $env:SystemDrive 'chef\\nodes') -Recurse -ErrorAction SilentlyContinue
if (! $ret) { exit 1 }
Remove-Item attributes.json
"""


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="az_run_chef.py",
        description="The script runs Chef Client in solo mode on the deployment VMs in the specified roles.",
    )

    parser.add_argument('-s', dest='site_id', help='Site Id')
    parser.add_argument('-d', dest='deployment_id', help='Deployment Id')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')
    parser.add_argument('-j', dest='json_attributes_secret', help='Key Vault secret name of role attributes')
    parser.add_argument('-e', dest='execution_timeout', type=int, default=3600, help='Execution timeout (seconds)')
    parser.add_argument("-v", dest="vault_name", help="Azure Key Vault name")
    parser.add_argument("-l", dest="log_level", default="info", help="Log level")

    args = parser.parse_args()

    if 'JSON_ATTRIBUTES' not in os.environ:
        raise RuntimeError("Environment variable 'JSON_ATTRIBUTES' is not set.")
    
    jsonAttributes = base64.b64decode(os.environ['JSON_ATTRIBUTES']).decode('utf-8')

    print("Creating a Key Vault secret with the JSON attributes...")

    credential = DefaultAzureCredential()
    vault_url = "https://{0}.vault.azure.net".format(args.vault_name)
    vault_client = SecretClient(vault_url=vault_url, credential=credential)
    vault_client.set_secret(args.json_attributes_secret, jsonAttributes)

    parameters = [
        {"name": "VaultName", "value": args.vault_name},
        {"name": "JsonAttributesSecret", "value": args.json_attributes_secret},
        {"name": "ManagedIdentityClientId", "value": "secret:vm-identity-client-id"},
        {"name": "LogLevel", "value": args.log_level},
    ]

    ret = az_utils.run_command(
        args.site_id,
        args.deployment_id,
        args.machine_roles,
        "run_chef",
        script,
        parameters,
        args.vault_name,
        int(args.execution_timeout)
    )

    vault_client.begin_delete_secret(args.json_attributes_secret).wait()
    vault_client.purge_deleted_secret(args.json_attributes_secret)

    exit(0 if ret else 1)
