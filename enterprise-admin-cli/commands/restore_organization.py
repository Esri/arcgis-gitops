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

from clients.exceptions import RestClientError, RestServiceError
import time
import commands.cli_utils as cli_utils

SLEEP_TIME = 10

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'restore-organization',
        'Restores the organization to the state it was in when the specified backup was created.')

    parser.add_argument('--store', dest='store', required=False, help='backup store name (if not specified - the default store is used)')
    parser.add_argument('--backup', dest='backup', required=False, help='backup name (if not specified - the latest backup is used)')
    parser.add_argument('--passcode', dest='passcode', required=True, help='pass code used to encrypt the backup')
    parser.add_argument('--wait', dest='wait', action='store_true', help='wait until the restore operation is completed')
    parser.add_argument('--timeout', dest='timeout', type=int, default=7200, help='restore operation timeout (seconds)')
    
    args = parser.parse_args()

    try:
        admin = cli_utils.create_admin_client(args)

        if args.store:
            store = args.store
        else:
            stores = admin.get_disaster_recovery_stores()['backupStores']
            store = next((s['name'] for s in stores if s['default']), None)

        if not store:
            raise ValueError("The backup store name is not specified and the default backup store is not configured.")

        if args.backup:
            backup = args.backup
        else:
            backups = admin.get_backups(store)['backups']
            # Sort backups by startTime in descending order and get the latest completed backup.
            backups = sorted(backups, key=lambda b: b['startTime'], reverse=True)
            backup = next((b['backupName'] for b in backups if b['status'] == 'completed'), None)

        if not backup:
            raise ValueError("There are no backups in the specified store.")

        admin.restore_organization(store, backup, args.passcode)

        print("Restoring organization from '{backup}' backup of '{store}' backup store.".format(backup=backup, store=store))

        if args.wait:
            print("Waiting for the restore operation to complete...")

            time.sleep(60.0)

            for i in range(args.timeout // SLEEP_TIME):
                try:
                    dr_status = admin.get_disaster_recovery_status()
                except (RestClientError, RestServiceError) as e:
                    # Restore operation results in the endpoint being temporarily unavailable.
                    time.sleep(SLEEP_TIME)
                    continue

                state = dr_status['status']['state']    

                if state == 'success':
                    print("Restore operation completed successfully.")
                    exit(0)
                elif state == 'completed_with_warnings':
                    print("Restore operation completed with warnings.")
                    print(dr_status['status']['message'])
                    exit(0)
                elif state == 'failed':
                    raise RestServiceError(500, "Restore operation failed.", 
                                           [dr_status['status']['message']])
                else:
                    time.sleep(SLEEP_TIME)
            
            raise RestServiceError(500, "Restore operation timed out.", 
                                   ["The restore operation did not complete within the specified timeout."])
    except Exception as e:
        print(e)
        exit(1)
