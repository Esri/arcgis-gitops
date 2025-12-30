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

from clients.exceptions import RestServiceError
import time
import commands.cli_utils as cli_utils
from datetime import datetime, timedelta

if __name__ == '__main__':
    parser = cli_utils.create_argument_parser(
        'create-backup',
        'Creates backup')

    parser.add_argument('--store', dest='store', required=False, help='backup store name (if not specified - the default store is used)')
    parser.add_argument('--backup', dest='backup', required=True, help='backup name')
    parser.add_argument('--passcode', dest='passcode', required=True, help='pass code that will be used to encrypt content of the backup')
    parser.add_argument('--description', dest='description', required=False, help='backup description')
    parser.add_argument('--retention', dest='retention', default=-1, type=int, help='backup retention time (days)')
    parser.add_argument('--wait', dest='wait', action='store_true', help='wait until the backup is completed')
    
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

        if args.retention > 0:
            epoch = datetime(1970, 1, 1)
            retention_date = round((datetime.now() + timedelta(days=args.retention) - epoch).total_seconds() * 1000)
        else:
            retention_date = args.retention

        job_info = admin.create_backup(store, args.backup, args.passcode, args.description, retention_date)

        print("Backup job submitted. Job ID: {job}".format(job = job_info['jobid']))

        if args.wait:
            print("Waiting for backup to complete...")
            
            while True:
                job_status = admin.get_job_status(job_info['jobid'])

                if job_status['status'] == 'COMPLETED':
                    print("Backup completed.")
                    if 'result' in job_status:
                        for stage in job_status['result']['stages']:
                            print("Stage '{name}' {state} in {duration}.".format(
                                name = stage['name'], state=stage['state'], duration = stage['duration']))
                    break
                elif job_status['status'] == 'FAILED':
                    raise RestServiceError(500, "Backup job failed.", job_status['messages'])
                elif job_status['status'] == 'CANCELLED':
                    raise RestServiceError(500, "Backup job cancelled.", job_status['messages'])
                elif job_status['status'] == 'TIMED OUT':
                    raise RestServiceError(500, "Backup job timed out.", job_status['messages'])
                else:
                    time.sleep(10)
    except Exception as e:
        print(e)
        exit(1)

