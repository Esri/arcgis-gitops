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

# The script runs a shell script on Azure VMs of a deployment.

import argparse
import base64
import os
import az_utils
import json
from azure.mgmt.compute.models import RunCommandInputParameter

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="az_run_shell_script.py",
        description="The script runs a shell script on Azure VMs of a deployment.",
    )

    parser.add_argument('-s', dest='enterprise_id', help='ArcGIS Enterprise ID')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment ID')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')
    parser.add_argument('-e', dest='execution_timeout', type=int, default=3600, help='Execution timeout (seconds)')
    parser.add_argument("-v", dest="vault_name", help="Azure Key Vault name")
    parser.add_argument('-f', dest='script_file', required=True, help='Script file path')
    parser.add_argument('--prepend', action='append', default=[], help='PowerShell helper to prepend in argument order')
    parser.add_argument('--vm-resource-id', help='Restrict execution to this exact Azure VM resource ID')
    parser.add_argument('--stream-output', action='store_true', help='Tail the protected command output blobs')
    parser.add_argument('--independent-fileserver', action='store_true',
                        help='Invoke the PowerShell script with its IndependentFileServer switch')

    args = parser.parse_args()

    if 'JSON_PARAMETERS' not in os.environ:
        raise RuntimeError("Environment variable 'JSON_PARAMETERS' is not set.")
    
    parts = []
    for script_path in [*args.prepend, args.script_file]:
        with open(script_path, encoding='utf-8') as file:
            parts.append(file.read())
    script = '\n'.join(parts)

    script = script.replace('\r\n', '\n')
    if args.independent_fileserver:
        if not args.vm_resource_id or args.machine_roles != "fileserver":
            parser.error("--independent-fileserver requires an exact file-server VM resource ID")
        script = ("$ErrorActionPreference = 'Stop'\ntry {\n& {\n" + script +
                  "\n} -IndependentFileServer\nexit 0\n"
                  "} catch { [Console]::Error.WriteLine($_.ToString()); "
                  "[Console]::Error.WriteLine($_.ScriptStackTrace); exit 1 }\n")

    json_parameters = base64.b64decode(os.environ['JSON_PARAMETERS']).decode('utf-8')

    # parse jsonParameters 
    try:
        parameters_dict = json.loads(json_parameters)
    except json.JSONDecodeError as e:
        raise ValueError(f"Failed to parse JSON_PARAMETERS: {e}")

    parameters = []
    for key, value in parameters_dict.items():
        parameters.append(RunCommandInputParameter(name=key, value=value))

    ret = az_utils.run_command(
        args.enterprise_id,
        args.deployment_id,
        args.machine_roles,
        os.path.splitext(os.path.basename(args.script_file))[0] if args.stream_output else "run_shell_script",
        script,
        script,
        parameters,
        args.vault_name,
        int(args.execution_timeout),
        vm_resource_id=args.vm_resource_id,
        stream_output=args.stream_output,
    )

    exit(0 if ret else 1)
