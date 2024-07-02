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
        'register-pv-backup-store', 
        'Registers or updates backup store in a persistent volume.')

    parser.add_argument('--store', dest='store', required=True, help='backup store name')
    parser.add_argument('--storage-class', dest='storage_class', required=True, help='backup volume storage class')
    parser.add_argument('--size', dest='size', required=True, help='backup volume size (e.g. 64Gi)')
    parser.add_argument('--is-dynamic', dest='is_dynamic', action='store_true', help='use dynamic volume provisioning type')
    parser.add_argument('--is-default', dest='is_default', action='store_true', help='make the store default')
    parser.add_argument("--label", dest='label', metavar="KEY=VALUE", nargs='+', help="key=value pair to identify and bind to a persistent volume")
    
    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)    
        
        stores = admin.get_disaster_recovery_stores()

        if args.store in [store['name'] for store in stores['backupStores']]:      
            admin.update_disaster_recovery_store(args.store, args.is_default)
            print("Backup store '{name}' updated.".format(name = args.store))
            exit(0)

        settings = {
            'type': 'HOSTED',
            'storageConfig': {
                'provisioningType': 'DYNAMIC' if args.is_dynamic else 'STATIC',
                'storageClass': args.storage_class,
                'size': args.size,
            }
        }

        if args.label:
            settings['storageConfig']['labels'] = {}
            for label in args.label:
                key, value = label.split('=', 1)
                settings['storageConfig']['labels'][key] = value

        ret = admin.register_disaster_recovery_store(args.store, settings, args.is_default)
       
        print("Backup store '{name}' registered.".format(name = args.store))
    except Exception as e:
        print(e)
        exit(1)
