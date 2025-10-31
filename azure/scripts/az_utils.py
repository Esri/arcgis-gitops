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

import os
import sys
import time
from datetime import datetime, timezone
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import VirtualMachineRunCommand
from azure.keyvault.secrets import SecretClient
from azure.storage.blob import BlobClient
from azure.core.exceptions import ResourceExistsError


# Runs a PowerShell script on VMs of the specified site Id, deployment Id, and machine roles
# using Azure Managed Run Command. Waits for the script to complete on all targeted VMs.
# Returns True if the command succeeded on all the VMs, False otherwise.
def run_command(
    site_id: str,       # ArcGIS Enterprise site Id
    deployment_id: str, # ArcGIS Enterprise deployment Id
    machine_roles: str, # comma-separated list of machine roles to target
    command_name: str,  # Command name
    script: str,        # PowerShell script to execute
    parameters: list,   # Script parameters
    vault_name: str,    # Azure Key Vault name
    timeout: int        # Execution timeout in seconds
): 
    if not site_id:
        print("Site id parameter is required.")
        return False
    
    if not deployment_id:
        print("Deployment id parameter is required.")
        return False

    if not machine_roles:
        print("Machine roles parameter is required.")
        return False

    if not command_name:
        print("Command name parameter is required.")
        return False

    if not script:
        print("Script parameter is required.")
        return False

    if not vault_name:
        print("Vault name parameter is required.")
        return False

    credential = DefaultAzureCredential()
    subscription_id = os.environ["ARM_SUBSCRIPTION_ID"]
    compute_client = ComputeManagementClient(credential, subscription_id)

    vault_url = "https://{0}.vault.azure.net".format(vault_name)
    vault_client = SecretClient(vault_url=vault_url, credential=credential)

    storage_account_name = vault_client.get_secret("storage-account-name").value

    managed_identity = {
        "object_id": vault_client.get_secret("vm-identity-principal-id").value
    }

    # If a parameter name starts with 'secret:', replace it with the corresponding secret value
    for param in parameters:
        if isinstance(param.get("value"), str) and param.get("value").startswith("secret:"):
            param["value"] = vault_client.get_secret(param["value"][7:]).value

    # Find all VMs with the specified tags
    vms = compute_client.virtual_machines.list_all()

    filtered_vms = []
    for vm in vms:
        if (
            vm.tags
            and vm.tags.get("ArcGISSiteId") == site_id
            and vm.tags.get("ArcGISDeploymentId") == deployment_id
            and vm.tags.get("ArcGISRole") in machine_roles.split(",")
        ):
            print(f"Found '{deployment_id}' deployment's '{vm.name}' VM in '{vm.provisioning_state}' state.")
            filtered_vms.append(vm)

    if not filtered_vms:
        print("No VMs found.")
        return False

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    # Start timer
    start_time = time.time()

    for vm in filtered_vms:
        resource_group = vm.id.split("/")[4]

        command_log = f"https://{storage_account_name}.blob.core.windows.net/logs/{site_id}/{deployment_id}/{vm.name}/{command_name}/{timestamp}"
        
        run_command = VirtualMachineRunCommand(
            location = vm.location,
            source = {
                "script": script
            },
            parameters = parameters,
            error_blob_uri = f"{command_log}/error",
            output_blob_uri = f"{command_log}/output",
            error_blob_managed_identity = managed_identity,
            output_blob_managed_identity = managed_identity,
            timeout_in_seconds = timeout,
            async_execution = True,
            treat_failure_as_deployment_failure = False,
            tags = {
                "ArcGISSiteId": site_id,
                "ArcGISDeploymentId": deployment_id
            }
        )
        
        try:
            create_run_command_poller = compute_client.virtual_machine_run_commands.begin_create_or_update(
                resource_group_name=resource_group,
                vm_name=vm.name,
                run_command_name=command_name,
                run_command=run_command
            )
        except ResourceExistsError as e:
            print(f"Command '{command_name}' on '{vm.name}' VM already exists: {e}")

            # Delete the existing command and try again
            compute_client.virtual_machine_run_commands.begin_delete(
                resource_group_name=resource_group,
                vm_name=vm.name,
                run_command_name=command_name).wait()

            create_run_command_poller = compute_client.virtual_machine_run_commands.begin_create_or_update(
                resource_group_name=resource_group,
                vm_name=vm.name,
                run_command_name=command_name,
                run_command=run_command
            )
            
        # Wait for the command creation process to complete.
        run_command = create_run_command_poller.result()
        print(f"Command '{run_command.name}' on '{vm.name}' VM created.")

    ret = True
    for vm in filtered_vms:
        resource_group = vm.id.split("/")[4]

        try:
            # Wait for the command to complete.
            while True:
                status = compute_client.virtual_machine_run_commands.get_by_virtual_machine(
                    resource_group_name=resource_group,
                    vm_name=vm.name,
                    run_command_name=command_name,
                    expand="instanceView"
                )

                if status.instance_view.execution_state != "Running":
                    elapsed_time = time.time() - start_time

                    instance_view = status.instance_view
                    
                    if instance_view.exit_code != 0:
                        ret = False

                    print(f"Command '{command_name}' on '{vm.name}' VM completed with status '{instance_view.execution_state}' ({instance_view.exit_code}) in {elapsed_time:.1f} seconds.")

                    blob = BlobClient.from_blob_url(status.output_blob_uri, credential=credential)
                    output = blob.download_blob().readall().decode("utf-8")
                    if output:
                        print(f"Command '{command_name}' output from '{vm.name}' VM:")
                        print(output)

                    blob = BlobClient.from_blob_url(status.error_blob_uri, credential=credential)
                    errors = blob.download_blob().readall().decode("utf-8")
                    if errors:
                        # write errors to stderr
                        print(f"Command '{command_name}' errors from '{vm.name}' VM:", file=sys.stderr)
                        print(errors, file=sys.stderr)

                    break

                # print(f"Waiting for command '{command_name}' on VM '{vm.name}' to complete...")
                time.sleep(10)
        except Exception as e:
            print(f"Command '{command_name}' on '{vm.name}' VM failed: {e}", file=sys.stderr)
            ret = False
        finally:
            compute_client.virtual_machine_run_commands.begin_delete(
                resource_group_name=resource_group,
                vm_name=vm.name,
                run_command_name=command_name).wait()

    print(f"All commands completed.")
    return ret
