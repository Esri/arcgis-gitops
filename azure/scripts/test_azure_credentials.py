# Copyright 2024 Esri
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

# Tests the Azure credentials configured in the system by accessing the specified blob container.

import argparse
import os
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='test_azure_credentials.py',
        description='Tests Azure credentials configured in the system by accessing the specified blob container.')

    parser.add_argument('-a', dest='account_name', required=True, help='Storage account name')
    parser.add_argument('-c', dest='container_name', required=True, help='Blob container name')

    args = parser.parse_args()

    try:
        print("Testing access to blob container '{0}' in '{1}' storage account...".format(args.container_name, args.account_name))

        account_url = "https://{0}.blob.core.windows.net".format(args.account_name)

        default_credential = DefaultAzureCredential()

        token = default_credential.get_token("https://storage.azure.com/.default")

        print("Service principal credential validated.")

        credential = os.environ['TERRAFORM_BACKEND_STORAGE_ACCOUNT_KEY'] if 'TERRAFORM_BACKEND_STORAGE_ACCOUNT_KEY' in os.environ else default_credential

        blob_service_client = BlobServiceClient(account_url, credential)

        blob_client = blob_service_client.get_blob_client(container=args.container_name, blob='test.txt')

        blob_client.upload_blob(b'test')
        
        print("Blob upload test succeeded.")

        blob_client.delete_blob()

        print("Blob delete test succeeded.")
    except Exception as e:
        print(e)
        exit(1)

    print("The test passed.")      
