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

from urllib.error import HTTPError, URLError
from clients.exceptions import RestClientError, RestServiceError  
import urllib.parse
import urllib.request
import json
import ssl

# The EnterpriseAdminClient class provides a Python client for the ArcGIS Enterprise Administrator API.
# See https://developers.arcgis.com/rest/enterprise-administration/enterprise/overview-of-the-arcgis-enterprise-admin-api.htm
class EnterpriseAdminClient:

    def __init__(self, enterprise_admin_url, username, password):
        self.enterprise_admin_url = enterprise_admin_url
        self.username = username
        self.password = password

    # Returns the organization site's state and logs from its configuration
    # See https://developers.arcgis.com/rest/enterprise-administration/enterprise/enterprise-admin-root.htm
    def get_info(self):

        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('GET', '/admin', data, token)

    # Returns the currently configured disaster recovery settings
    # https://developers.arcgis.com/rest/enterprise-administration/enterprise/settings.htm
    def get_disaster_recovery_settings(self):
        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('GET', '/admin/system/disasterrecovery/settings', data, token)
    

    # Updates disaster recovery settings.
    # See: https://developers.arcgis.com/rest/enterprise-administration/enterprise/update-settings.htm
    def update_disaster_recovery_settings(self, storage_class: str, size: str, timeout_in_seconds: int):
        if storage_class is None:
            raise ValueError('Storage class is not specified.')

        if size is None:
            raise ValueError('Storage size is not specified.')

        token = self.generate_token()

        settings = {
            'stagingVolumeConfig': {
                'provisioningType': 'DYNAMIC'
            }
        }

        if storage_class is not None:
            settings['stagingVolumeConfig']['storageClass'] = storage_class
        
        if size is not None:
            settings['stagingVolumeConfig']['size'] = size    
        
        if timeout_in_seconds is not None:
            settings['timeoutInSeconds'] = timeout_in_seconds

        data = {
            'settings': json.dumps(settings),
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/disasterrecovery/settings/update', data, token)


    # Returns information about a specified backup store.
    # See: https://developers.arcgis.com/rest/enterprise-administration/enterprise/backup-store.htm
    def get_disaster_recovery_store(self, store: str):
        if store is None:
            raise ValueError('Store name is not specified.')

        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('GET', "/admin/system/disasterrecovery/stores/{store}".format(store=store), data, token)


    # Returns backup stores registered with the deployment.
    # See: https://developers.arcgis.com/rest/enterprise-administration/enterprise/stores.htm
    def get_disaster_recovery_stores(self):
        token = self.generate_token()
        
        data = {
            'f': 'json'
        }

        return self.send_request('GET', '/admin/system/disasterrecovery/stores', data, token)

    # Returns information about the last submitted disaster recovery job
    # https://developers.arcgis.com/rest/enterprise-administration/enterprise/status.htm
    def get_disaster_recovery_status(self):
        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('GET', '/admin/system/disasterrecovery/status', data, token)

    # Registers a backup store.
    # See: https://developers.arcgis.com/rest/enterprise-administration/enterprise/register.htm
    def register_disaster_recovery_store(self, store: str, settings: dict, is_default: bool):
        if store is None:
            raise ValueError('Store name is not specified.')

        if settings is None:
            raise ValueError('Store settings are not specified.')

        token = self.generate_token()

        data = {
            'storeName': store,
            'settings': json.dumps(settings),
            'isDefault': is_default,
            'async': False,
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/disasterrecovery/stores/register', data, token)
    
    # Updates a backup store.
    # https://developers.arcgis.com/rest/enterprise-administration/enterprise/update-backup-store.htm
    def update_disaster_recovery_store(self, store: str, is_default: bool):
        if store is None:
            raise ValueError('Store name is not specified.')

        token = self.generate_token()

        settings = {
            'default': is_default
        }

        data = {
            'settings': json.dumps(settings),
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/disasterrecovery/stores/{store}/update'.format(store=store), data, token)
    
    # Unregisters a backup store.
    # https://developers.arcgis.com/rest/enterprise-administration/enterprise/unregister-backup-store.htm
    def unregister_disaster_recovery_store(self, store: str):
        if store is None:
            raise ValueError('Store name is not specified.')

        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/disasterrecovery/stores/{store}/unregister'.format(store=store), data, token)
    
    # Returns the backups that have been created for the organization
    # See https://developers.arcgis.com/rest/enterprise-administration/enterprise/backups.htm
    def get_backups(self, store: str):
        if store is None:
            raise ValueError('Store name is not specified.')

        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('GET', '/admin/system/disasterrecovery/stores/{store}/backups'.format(store=store), data, token)

    # Creates a backup of the deployment.
    # See https://developers.arcgis.com/rest/enterprise-administration/enterprise/create-backup.htm
    def create_backup(self, store: str, backup: str, passcode: str, description: str, retention: str):
        if store is None:
            raise ValueError('Store name is not specified.')

        if backup is None:
            raise ValueError('Backup name is not specified.')

        if passcode is None:
            raise ValueError('Backup passcode is not specified.')

        token = self.generate_token()

        data = {
            'name': backup,
            'passcode': passcode,
            'description': description,
            'retentionDate': retention,
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/disasterrecovery/stores/{store}/backups/create'.format(store=store), data, token)
    
    # Restores the organization to the state it was in when a specific backup was created.
    # https://developers.arcgis.com/rest/enterprise-administration/enterprise/restore-backup.htm
    def restore_organization(self, store: str, backup: str, passcode: str):
        if store is None:
            raise ValueError('Store name is not specified.')

        if backup is None:
            raise ValueError('Backup name is not specified.')

        if passcode is None:
            raise ValueError('Backup passcode is not specified.')

        token = self.generate_token()

        data = {
            'passcode': passcode,
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/disasterrecovery/stores/{store}/backups/{backup}/restore'.format(store=store, backup=backup), data, token)
    
    # Get job status
    # https://developers.arcgis.com/rest/enterprise-administration/enterprise/job.htm
    def get_job_status(self, jobid: str):
        if jobid is None:
            raise ValueError('Job ID is not specified.')

        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('GET', '/admin/jobs/{job}'.format(job=jobid), data, token)

    # Generate an access token
    # https://developers.arcgis.com/rest/users-groups-and-items/generate-token.htm
    def generate_token(self, referer='referer', expiration=60):
        data = {
            'username': self.username,
            'password': self.password,
            'client': 'referer',
            'referer': referer,
            'expiration': str(expiration),
            'f': 'json'
        }

        return self.send_request('POST', '/sharing/rest/generateToken', data, None)['token']

        
    def send_request(self, method, url, data, token):
        try:
            request = urllib.request.Request(self.enterprise_admin_url + url)
            
            request.method = method

            if data is not None:
                request.data = urllib.parse.urlencode(data).encode('utf-8')

            if token is not None:
                request.add_header('Authorization', 'Bearer ' + token)

            response = urllib.request.urlopen(
                request, context=ssl._create_unverified_context())
      
            if response.code > 200:
                raise RestServiceError(response.code, response.read().decode())

            json_response = json.loads(response.read().decode())

            if 'error' in json_response:
                error = json_response['error']
                raise RestServiceError(error['code'], error['message'], error['details'] )

            return json_response
        except HTTPError as e:
            raise RestClientError(e.code, e.msg, e.url)
        except URLError as e:
            raise RestClientError(500, e.reason)
