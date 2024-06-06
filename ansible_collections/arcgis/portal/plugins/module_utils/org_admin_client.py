from urllib.error import HTTPError, URLError
from ansible_collections.arcgis.common.plugins.module_utils.exceptions import RestClientError, RestServiceError  
import urllib.parse
import urllib.request
import json
import ssl
import time

MAX_RETRIES = 100
SLEEP_TIME = 10.0

# The OrgAdminClient class provides a python client for Enterprise Administration REST API
# for managing federated servers in Portal for ArcGIS and ArcGIS Enterprise on Kubernetes.
# See https://developers.arcgis.com/rest/enterprise-administration/enterprise/organization/
# And https://developers.arcgis.com/rest/enterprise-administration/portal/federation/
class OrgAdminClient:

    def __init__(self, portal_url, username, password, org_id=None):
        if org_id is None:
            self.admin_url = portal_url + '/portaladmin'
        else:
            self.admin_url = portal_url + '/admin/orgs/' + org_id
        self.sharing_url = portal_url + '/sharing'
        self.username = username
        self.password = password

    # Wait for 1000 seconds until the server admin URL is available
    def wait_until_available(self):
        url = self.admin_url + '/?f=json'

        for i in range(MAX_RETRIES):
            if self.url_available(url):
                return

            time.sleep(SLEEP_TIME)

        raise RestClientError(500, 'The server did not become available in the expected time.')


    # Retrieve the list of federated servers
    # See https://developers.arcgis.com/rest/users-groups-and-items/servers/
    def get_servers(self):
        token = self.generate_token()

        return self.send_request('GET', self.sharing_url + '/rest/portals/self/servers/?f=json', None, token)


    # Federate a server
    # See https://developers.arcgis.com/rest/enterprise-administration/portal/federate-servers/
    # And https://developers.arcgis.com/rest/enterprise-administration/enterprise/federate-server/
    def federate_server(self, server_url, admin_url, username, password):
        token = self.generate_token()

        data = {
            'url': server_url,
            'adminUrl': admin_url,
            'username': username,
            'password': password,
            'f': 'json'
        }

        return self.send_request('POST', self.admin_url + '/federation/servers/federate', data, token)

    
    # Update federated server role and function
    # See https://developers.arcgis.com/rest/enterprise-administration/portal/update-server/
    # And https://developers.arcgis.com/rest/enterprise-administration/enterprise/update-server/
    def update_server(self, server_id, server_role, server_function):
        token = self.generate_token()

        data = {
            'serverRole': server_role,
            'serverFunction': server_function,
            'f': 'json'
        }

        return self.send_request('POST', self.admin_url + '/federation/servers/' + server_id + '/update', data, token)
    

    # Generate an access token
    # See https://developers.arcgis.com/rest/users-groups-and-items/generate-token/
    def generate_token(self, referer='referer', expiration=60):
        data = {
            'username': self.username,
            'password': self.password,
            'client': 'referer',
            'referer': referer,
            'expiration': str(expiration),
            'f': 'json'
        }

        return self.send_request('POST', self.sharing_url + '/rest/generateToken', data, None)['token']

        
    def send_request(self, method, url, data, token):
        try:
            request = urllib.request.Request(url)
            
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

            if 'error' in json_response:
                error = json_response['error']
                details = str(error['details']) if 'details' in error else None
                raise RestServiceError(error['code'], error['message'], details)

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
       
    