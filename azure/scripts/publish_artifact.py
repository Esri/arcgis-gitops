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

# Retrieves VM image Id from packer-manifest.json file and saves in Azure Key Vault secret.

import argparse
import json

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='publish_artifact.py',
        description='Retrieves VM image Id from packer-manifest.json file and saves in Azure Key Vault secret.')

    parser.add_argument('-v', dest='vault_name', help='Key Vault name')
    parser.add_argument('-s', dest='secret_name', help='Key Vault secret name')
    parser.add_argument('-f', dest='manifest', help='packer-manifest.json file path')
    parser.add_argument('-r', dest='packer_run_uuid', help='Packer run UUID')

    args = parser.parse_args()

    with open(args.manifest, encoding="utf-8") as fp:
        manifest = json.load(fp)

    image_id = None
    
    for build in manifest['builds']:
        if build['packer_run_uuid'] == args.packer_run_uuid:
            image_id = build['artifact_id']

    if image_id is None:
        print("The packer run UUID not found in {0} manifest file.".format(args.manifest))
        exit(1)

    credential = DefaultAzureCredential()
    vault_url = "https://{0}.vault.azure.net".format(args.vault_name)
    client = SecretClient(vault_url=vault_url, credential=credential)
    client.set_secret(args.secret_name, image_id)

    print("Image Id '{0}' stored in a Key Vault secret.".format(image_id))