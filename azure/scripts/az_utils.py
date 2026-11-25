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

import os
import sys
import time
import codecs
from datetime import datetime, timezone
from typing import Optional
from uuid import uuid4
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import VirtualMachineRunCommand
from azure.mgmt.compute.models import VirtualMachineRunCommandScriptSource
from azure.mgmt.compute.models import RunCommandInputParameter
from azure.mgmt.compute.models import RunCommandManagedIdentity
from azure.keyvault.secrets import SecretClient
from azure.storage.blob import BlobClient
from azure.core.exceptions import AzureError, ResourceExistsError, ResourceNotFoundError

SLEEP_TIME = 10


class CommandOutput:
    def __init__(self, blob: BlobClient, label: str, stream: str):
        self.blob = blob
        self.label = f"{label} [{stream}]"
        self.destination = sys.stderr if stream == "stderr" else sys.stdout
        self.offset = 0
        self.pending = ""
        self.decoder = codecs.getincrementaldecoder("utf-8-sig")(errors="replace")

    def read(self) -> bool:
        try:
            size = self.blob.get_blob_properties().size
        except ResourceNotFoundError:
            return False
        if size < self.offset:
            raise ValueError("Command output blob shrank.")
        if size > self.offset:
            download = self.blob.download_blob(offset=self.offset, length=size - self.offset)
            for chunk in download.chunks():
                self.offset += len(chunk)
                self._write(self.decoder.decode(chunk))
        return True

    def finish(self):
        self._write(self.decoder.decode(b"", final=True), final=True)

    def _write(self, text: str, final: bool = False):
        *lines, self.pending = (self.pending + text).split("\n")
        if final and self.pending:
            lines.append(self.pending)
            self.pending = ""
        for line in lines:
            for part in line.rstrip("\r").split("\r"):
                safe = part.replace(chr(27), r"\x1b")
                print(f"{self.label} {safe}", file=self.destination, flush=True)


def wait_with_output(commands, resource_group, vm, name, outputs, timeout):
    label = outputs[0].label.rsplit(" ", 1)[0]
    deadline = time.monotonic() + timeout + 600
    status = None
    while time.monotonic() < deadline:
        status = commands.get_by_virtual_machine(
            resource_group_name=resource_group, vm_name=vm, run_command_name=name,
            expand="instanceView").instance_view
        if status and status.execution_state not in (None, "Unknown", "Pending", "Running"):
            break
        for stream in outputs:
            try:
                stream.read()
            except (AzureError, ValueError):
                # Retry from the last consumed byte during the final drain.
                pass
        time.sleep(SLEEP_TIME)
    else:
        print(f"{label} Wait timed out; command may still be running.", file=sys.stderr, flush=True)
        return False, False

    print(f"{label} {status.execution_state} (exit {status.exit_code})", flush=True)
    collected = True
    for stream, excerpt in zip(outputs, (status.output, status.error)):
        drain_deadline = time.monotonic() + 30
        previous_size = None
        while True:
            try:
                exists = stream.read()
                if exists and previous_size == stream.offset and (stream.offset or not excerpt):
                    stream.finish()
                    break
                if not exists and not excerpt and previous_size == 0:
                    stream.finish()
                    break
                previous_size = stream.offset
            except (AzureError, ValueError) as exc:
                print(f"{stream.label} Could not retrieve full output ({type(exc).__name__}).",
                      file=sys.stderr, flush=True)
                collected = False
                stream.finish()
                break
            if time.monotonic() >= drain_deadline:
                print(f"{stream.label} Full output blob unavailable.", file=sys.stderr, flush=True)
                collected = False
                stream.finish()
                break
            time.sleep(3)
        if excerpt and stream.offset == 0:
            print(f"{stream.label} Provider excerpt may be truncated.", file=sys.stderr, flush=True)
            stream._write(excerpt, final=True)
    return status.execution_state == "Succeeded" and status.exit_code == 0 and collected, True

# Runs a PowerShell script on VMs of the specified enterprise ID, deployment ID, and machine roles
# using Azure Managed Run Command. Waits for the script to complete on all targeted VMs.
# Returns True if the command succeeded on all the VMs, False otherwise.
def run_command(
    enterprise_id: str, # ArcGIS Enterprise ID
    deployment_id: str, # ArcGIS Enterprise deployment ID
    machine_roles: str, # comma-separated list of machine roles to target
    command_name: str,  # Command name
    windows_script: str,        # PowerShell script to execute
    linux_script: str,        # Shell script to execute
    parameters: list[RunCommandInputParameter], # Script parameters
    vault_name: str,    # Azure Key Vault name
    timeout: int,       # Execution timeout in seconds
    vm_resource_id: Optional[str] = None,
    stream_output: bool = False,
): 
    if not enterprise_id:
        print("ArcGIS Enterprise ID parameter is required.")
        return False
    
    if not deployment_id:
        print("ArcGIS Enterprise deployment ID parameter is required.")
        return False

    if not machine_roles:
        print("Machine roles parameter is required.")
        return False

    if not command_name:
        print("Command name parameter is required.")
        return False

    if not windows_script and not linux_script:
        print("windows_script or linux_script parameter is required.")
        return False

    if not vault_name:
        print("Vault name parameter is required.")
        return False
    
    if "ARM_SUBSCRIPTION_ID" not in os.environ:
        print("ARM_SUBSCRIPTION_ID environment variable is required.")
        return False

    credential = DefaultAzureCredential()
    subscription_id = os.environ["ARM_SUBSCRIPTION_ID"]
    compute_client = ComputeManagementClient(credential, subscription_id)

    vault_url = "https://{0}.vault.azure.net".format(vault_name)
    vault_client = SecretClient(vault_url=vault_url, credential=credential)

    storage_account_name = vault_client.get_secret("storage-account-name").value

    managed_identity = RunCommandManagedIdentity(
        client_id=vault_client.get_secret("vm-identity-client-id").value
    )

    # If a parameter value starts with 'secret:', replace it with the corresponding secret value
    if parameters:
        for param in parameters:
            if isinstance(param.value, str) and param.value.startswith("secret:"):
                param.value = vault_client.get_secret(param.value[7:]).value

    # Find all VMs with the specified tags
    vms = compute_client.virtual_machines.list_all()

    filtered_vms = []

    roles = [role.strip() for role in machine_roles.split(",")]
    
    for vm in vms:
        if (
            (not vm_resource_id or vm.id.casefold() == vm_resource_id.casefold())
            and vm.tags
            and vm.tags.get("ArcGISEnterpriseID") == enterprise_id
            and vm.tags.get("ArcGISDeploymentID") == deployment_id
            and vm.tags.get("ArcGISRole") in roles
        ):
            print(f"Found '{deployment_id}' deployment's '{vm.name}' VM in '{vm.provisioning_state}' state.")
            filtered_vms.append(vm)

    if not filtered_vms:
        print("No VMs found.")
        return False
    
    # Wait up to 10 minutes for VMs to be in 'Succeeded' provisioning state
    for vm in filtered_vms:
        resource_group = vm.id.split("/")[4]
        provisioned = False
        
        for _ in range(60):
            vm_instance = compute_client.virtual_machines.get(
                resource_group_name=resource_group,
                vm_name=vm.name,
                expand="instanceView"
            )

            if vm_instance.provisioning_state == "Succeeded":
                provisioned = True
                # print(f"VM '{vm.name}' is in 'Succeeded' provisioning state.")
                break
            
            print(f"Waiting for VM '{vm.name}' to be in 'Succeeded' provisioning state...")
            time.sleep(SLEEP_TIME)
        
        if not provisioned:
            print(f"VM '{vm.name}' is not in 'Succeeded' provisioning state. Current state: '{vm_instance.provisioning_state}'.")
            return False
    
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    if stream_output:
        command_name = f"{command_name}-{uuid4().hex[:12]}"
    # Start timer
    start_time = time.time()

    for vm in filtered_vms:
        resource_group = vm.id.split("/")[4]

        vm_instance = compute_client.virtual_machines.get(
            resource_group_name=resource_group,
            vm_name=vm.name,
            expand="instanceView"
        )

        os_type = vm_instance.storage_profile.os_disk.os_type

        command_log = f"https://{storage_account_name}.blob.core.windows.net/logs/{enterprise_id}/{deployment_id}/{vm.name}/{command_name}/{timestamp}"
        
        run_command = VirtualMachineRunCommand(
            location = vm.location,
            source = VirtualMachineRunCommandScriptSource(script=windows_script if os_type == "Windows" else linux_script),
            parameters = parameters,
            error_blob_uri = f"{command_log}/error",
            output_blob_uri = f"{command_log}/output",
            error_blob_managed_identity = managed_identity,
            output_blob_managed_identity = managed_identity,
            timeout_in_seconds = timeout,
            async_execution = True,
            treat_failure_as_deployment_failure = False,
            tags = {
                "ArcGISEnterpriseID": enterprise_id,
                "ArcGISDeploymentID": deployment_id
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
            if stream_output:
                raise
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

        if stream_output:
            label = f"[Azure {vm.tags['ArcGISRole']} {vm.name} {command_name}]"
            outputs = [
                CommandOutput(BlobClient.from_blob_url(f"{command_log}/{suffix}", credential=credential),
                              label, stream)
                for suffix, stream in (("output", "stdout"), ("error", "stderr"))
            ]
            commands = compute_client.virtual_machine_run_commands
            try:
                succeeded, terminal = wait_with_output(commands, resource_group, vm.name,
                                                       command_name, outputs, timeout)
            except AzureError as exc:
                print(f"{label} Could not determine command state ({type(exc).__name__}); "
                      "check Managed Run Command before retrying.", file=sys.stderr, flush=True)
                return False
            if terminal:
                try:
                    commands.begin_delete(resource_group_name=resource_group, vm_name=vm.name,
                                          run_command_name=command_name).wait(timeout=60)
                except AzureError as exc:
                    print(f"{label} Cleanup failed ({type(exc).__name__}).", file=sys.stderr, flush=True)
                    succeeded = False
            if not succeeded:
                return False

    if stream_output:
        return True

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

                if status.instance_view.execution_state not in ("Pending", "Running"):
                    elapsed_time = time.time() - start_time

                    instance_view = status.instance_view
                    
                    if instance_view.execution_state != "Succeeded" or instance_view.exit_code != 0:
                        ret = False

                    print(f"Command '{command_name}' on '{vm.name}' VM completed with status '{instance_view.execution_state}' ({instance_view.exit_code}) in {elapsed_time:.1f} seconds.")

                    if status.output_blob_uri:
                        blob = BlobClient.from_blob_url(status.output_blob_uri, credential=credential)
                        if blob.exists():
                            output = blob.download_blob().readall().decode("utf-8")
                            if output:
                                print(f"Command '{command_name}' stdout from '{vm.name}' VM:")
                                print(output)

                    if status.error_blob_uri:
                        blob = BlobClient.from_blob_url(status.error_blob_uri, credential=credential)
                        if blob.exists():
                            errors = blob.download_blob().readall().decode("utf-8")
                            if errors:
                                # write errors to stderr
                                print(f"Command '{command_name}' stderr from '{vm.name}' VM:", file=sys.stderr)
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
