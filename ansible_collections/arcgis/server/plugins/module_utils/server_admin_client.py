from urllib.error import HTTPError, URLError
from ansible_collections.arcgis.common.plugins.module_utils.exceptions import RestClientError, RestServiceError
import urllib.parse
import urllib.request
import json
import ssl
import time

MAX_RETRIES = 100
SLEEP_TIME = 10.0

# The ServerAdminClient class provides a Python client for the ArcGIS Server Administrator REST API.
# See https://developers.arcgis.com/rest/enterprise-administration/server/overview/
class ServerAdminClient:

    def __init__(self, server_admin_url, username, password):
        self.server_admin_url = server_admin_url
        self.username = username
        self.password = password

    def wait_until_available(self):
        url = self.server_admin_url + '/admin/?f=json'

        for i in range(MAX_RETRIES):
            if self.url_available(url):
                return

            time.sleep(SLEEP_TIME)

        raise RestClientError(500, 'The server did not become available in the expected time.')

    # Returns the organization site's state and logs from its configuration
    # See https://developers.arcgis.com/rest/enterprise-administration/server/site/
    def get_info(self):
        token = self.generate_token()

        return self.send_request('GET', '/admin/?f=json', None, token)

    def site_exists(self):
        url = self.server_admin_url + '/admin/?f=json'
        request = urllib.request.Request(url)
        request.method = 'GET'
        response = urllib.request.urlopen(request, context=ssl._create_unverified_context())

        if response.code == 200:
            json_response = json.loads(response.read().decode())
            if json_response['code'] == 499:
                return True

        return False
    
    # Check upgrade status
    # See https://developers.arcgis.com/rest/enterprise-administration/server/upgrade/
    def upgrade_required(self):
        url = self.server_admin_url + '/admin/upgrade?f=json'
        request = urllib.request.Request(url)
        request.method = 'GET'
        response = urllib.request.urlopen(request, context=ssl._create_unverified_context())

        if response.code != 200:
            return False

        json_response = json.loads(response.read().decode())
        return ('upgradeStatus' in json_response and json_response['upgradeStatus'] in ['UPGRADE_REQUIRED', 'LAST_ATTEMPT_FAILED']) or \
               ('isUpgrade' in json_response and  json_response['isUpgrade'])

    # Upgrade the ArcGIS Server site
    # See https://developers.arcgis.com/rest/enterprise-administration/server/upgrade/
    def complete_upgrade(self):
        data = {
            'f': 'json'
        }

        return self.send_request('POST', '/admin/upgrade', data, None)

    # Creates a new ArcGIS Server site
    # See https://developers.arcgis.com/rest/enterprise-administration/server/createsite/
    def create_site(self, config_store_connection, directories, settings, runAsync):
        data = {
            'username': self.username,
            'password': self.password,
            'runAsync': runAsync,
            'f': 'json'
        }

        if config_store_connection is not None:
            data['configStoreConnection'] = json.dumps(config_store_connection)

        if directories is not None:
            data['directories'] = json.dumps(directories)

        if settings is not None:
            data['settings'] = json.dumps(settings)

        return self.send_request('POST', '/admin/createNewSite', data, None)

    # Joins an existing ArcGIS Server site
    # See https://developers.arcgis.com/rest/enterprise-administration/server/joinsite/
    def join_site(self, primary_server_url, pull_license = False):
        data = {
            'adminURL': primary_server_url,
            'username': self.username,
            'password': self.password,
            'pullLicense': pull_license,
            'f': 'json'
        }

        return self.send_request('POST', '/admin/joinSite', data, None)
    
    
    # Get system properties
    # See https://developers.arcgis.com/rest/enterprise-administration/server/serverproperties/
    def get_system_properties(self):
        token = self.generate_token()

        return self.send_request('GET', '/admin/system/properties/?f=json', None, token)
    

    # Update system properties
    # See https://developers.arcgis.com/rest/enterprise-administration/server/updateserverproperties/
    def update_system_properties(self, properties):
        token = self.generate_token()

        data = {
            'properties': json.dumps(properties),
            'f': 'json'
        }

        return self.send_request('POST', '/admin/system/properties/update', data, token)
    

    # Get services directory properties
    # See https://developers.arcgis.com/rest/enterprise-administration/server/handlersrestservicesdirectory/
    def get_services_directory_properties(self):
        token = self.generate_token()

        return self.send_request('GET', '/admin/system/handlers/rest/servicesdirectory/?f=json', None, token)

    # Edit services directory properties
    # See https://developers.arcgis.com/rest/enterprise-administration/server/handlersrestservicesdirectoryedit/
    def edit_services_directory_properties(self, services_dir_enabled : bool):
        token = self.generate_token()

        properties = self.get_services_directory_properties()

        properties['servicesDirEnabled'] = 'true' if services_dir_enabled else 'false'
        properties['f'] = 'json'

        return self.send_request('POST', '/admin/system/handlers/rest/servicesdirectory/edit', properties, token)


    # Generate an access token
    # See https://developers.arcgis.com/rest/enterprise-administration/server/generatetoken/
    def generate_token(self, referer='referer', expiration=60):
        data = {
            'username': self.username,
            'password': self.password,
            'client': 'referer',
            'referer': referer,
            'expiration': str(expiration),
            'f': 'json'
        }

        return self.send_request('POST', '/admin/generateToken', data, None)['token']

        
    def send_request(self, method, url, data, token):
        try:
            request = urllib.request.Request(self.server_admin_url + url)
            
            request.method = method

            request.add_header('Referer', 'referer')

            if data is not None:
                request.data = urllib.parse.urlencode(data).encode('utf-8')

            if token is not None:
                request.add_header('Authorization', 'Bearer ' + token)

            response = urllib.request.urlopen(
                request, context=ssl._create_unverified_context())
      
            if response.code > 200:
                raise RestServiceError(response.code, response.read().decode())

            json_response = json.loads(response.read().decode())

            if 'status' in json_response and json_response['status'] == 'error':
                raise RestServiceError(json_response['code'], ' '.join(json_response['messages']))

            return json_response
        except HTTPError as e:
            raise RestClientError(e.code, e.msg, e.url)
        except URLError as e:
            raise RestClientError(500, e.reason)

    
    def url_available(self, url):
        try:
            request = urllib.request.Request(url)
            request.method = 'GET'

            response = urllib.request.urlopen(request, context=ssl._create_unverified_context())

            return response.code < 400
        except:
            return False
       
    