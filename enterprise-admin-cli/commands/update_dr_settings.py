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
        'update-dr-settings',
        'Updates the disaster recovery settings.')

    parser.add_argument('--storage-class', dest='storage_class', required=True, help='staging volume storage class')
    parser.add_argument('--size', dest='size', required=True, help='staging volume size (e.g. 64Gi)')
    parser.add_argument('--timeout', dest='timeout', type=int, required=False, help='backup job timeout (seconds)')
    
    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)

        ret = admin.update_disaster_recovery_settings(args.storage_class, args.size, args.timeout)
        
        print("Disaster recovery settings updated.")
    except Exception as e:
        print(e)
        exit(1)

