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

# Deletes VM images used by the specified deployment and Key Vault secrets referencing the images.

import argparse
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.keyvault import KeyVaultManagementClient
from azure.keyvault.secrets import SecretClient

def delete_vm_images(compute_client, arcgis_site_id, arcgis_deployment_id):
    matched_images = []

    # Enumerate all managed images in the subscription
    for image in compute_client.images.list():
        tags = image.tags or {}

        if (tags.get("ArcGISSiteId") == arcgis_site_id and
            tags.get("ArcGISDeploymentId") == arcgis_deployment_id):
            matched_images.append({
                "name": image.name,
                "resource_group": image.id.split("/")[4],
                "location": image.location,
                "id": image.id,
                "tags": tags
            })

    for image in matched_images:
        print(f'Deleting VM image {image["name"]}...')
        compute_client.images.begin_delete(image["resource_group"], image["name"]).wait()


def delete_vm_image_secrets(kv_mgmt_client, credential, arcgis_site_id, arcgis_deployment_id):
    vaults = kv_mgmt_client.vaults.list()

    for vault in vaults:
        if vault.tags and vault.tags.get("ArcGISSiteId") == arcgis_site_id:
            key_vault_url = "https://{0}.vault.azure.net".format(vault.name)
            break
    else:
        print(f'No Key Vault found for site {arcgis_site_id}')
        key_vault_url = None

    if key_vault_url:
        secret_client = SecretClient(vault_url=key_vault_url, credential=credential)

        secret_prefix = f'vm-image-{arcgis_site_id}-{arcgis_deployment_id}-'
        
        secrets = secret_client.list_properties_of_secrets()
        
        secrets_to_delete = [s.name for s in secrets if s.name.startswith(secret_prefix)]

        for secret_name in secrets_to_delete:
            try:
                print(f'Deleting Key Vault secret {secret_name}...')
                secret_client.begin_delete_secret(secret_name).wait()
                secret_client.purge_deleted_secret(secret_name)
            except Exception as e:
                print(f'Warning: Could not delete secret {secret_name}. It may not exist. Error: {e}')  


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='delete_deployment_images.py',
        description='Deletes VM images used by the specified deployment and Key Vault secrets referencing the images.')

    parser.add_argument('-s', dest='site_id', required=True, help='ArcGIS Enterprise site Id')
    parser.add_argument('-d', dest='deployment_id', required=True, help='ArcGIS Enterprise deployment Id')
    parser.add_argument('-u', dest='subscription_id', required=True, help='Azure Subscription Id')

    args = parser.parse_args()

    print(f'Deleting VM images for deployment \"{args.deployment_id}\" in site \"{args.site_id}\"...')

    # Authenticate using DefaultAzureCredential (supports env vars, managed identity, CLI login, etc.)
    credential = DefaultAzureCredential()

    compute_client = ComputeManagementClient(credential, args.subscription_id)

    delete_vm_images(compute_client, args.site_id, args.deployment_id)

    kv_mgmt_client = KeyVaultManagementClient(credential, args.subscription_id)

    delete_vm_image_secrets(kv_mgmt_client, credential, args.site_id, args.deployment_id)

    print('Done.')