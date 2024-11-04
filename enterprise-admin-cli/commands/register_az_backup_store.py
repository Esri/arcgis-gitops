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

import commands.cli_utils as cli_utils

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'register-az-backup-store', 
        'Registers or updates backup store in Microsoft Azure blobs.')

    parser.add_argument('--store', dest='store', required=True, help='backup store name')
    parser.add_argument('--storage-account', dest='storage_account', required=True, help='Azure storage account name')
    parser.add_argument('--account-endpoint-url', dest='account_endpoint_url', default=None, help='Blob service endpoint URL')
    parser.add_argument('--root', dest='root', default='backups', help='blob container root directory')
    parser.add_argument('--is-default', dest='is_default', action='store_true', help='make the store default')
    parser.add_argument('--client-id', dest='client_id', help='User-assigned managed identity client Id')
    
    args = parser.parse_args()

    if args.account_endpoint_url is None:
        account_endpoint_url = "https://{account}.blob.core.windows.net".format(account = args.storage_account),
    else:
        account_endpoint_url = args.account_endpoint_url

    try:
        admin = cli_utils.create_admin_client(args)    
        
        stores = admin.get_disaster_recovery_stores()

        if args.store in [store['name'] for store in stores['backupStores']]:      
            admin.update_disaster_recovery_store(args.store, args.is_default)
            print("Backup store '{name}' updated.".format(name = args.store))
            exit(0)

        settings = {
            'type': 'AZURE_BLOBSTORE',
            'provider': {
                'name': 'AZURE',
                'cloudServices': [{
                    'name': 'Azure Blob Store',
                    'type': 'objectStore',
                    'usage': 'BACKUP',
                    'connection': {
                        'containerName': 'backups',
                        'rootDir': args.root,
                        'accountEndpointUrl': account_endpoint_url,
                        'credential': {
                            'managedIdentityClientId': args.client_id,
                            'secret': {
                                'storageAccountName': args.storage_account
                            },
                            'type': 'USER-ASSIGNED-IDENTITY'
                        }
                    },
                    'category': 'storage'
                }]
            }
        }

        ret = admin.register_disaster_recovery_store(args.store, settings, args.is_default)
       
        print("Backup store '{name}' registered.".format(name = args.store))
    except Exception as e:
        print(e)
        exit(1)
