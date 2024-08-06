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
from ansible_collections.arcgis.common.plugins.module_utils.exceptions import RestClientError, RestServiceError
from requests_toolbelt.multipart.encoder import MultipartEncoder
import urllib.parse
import urllib.request
import requests
import os.path
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

    # Get registered ArcGIS Web Adaptors
    # See https://developers.arcgis.com/rest/enterprise-administration/server/webadaptors/
    def get_web_adaptors(self):
        token = self.generate_token()

        return self.send_request('GET', '/admin/system/webadaptors/?f=json', None, token)['webAdaptors']

    # Unregister an ArcGIS Web Adaptor
    # See https://developers.arcgis.com/rest/enterprise-administration/server/unregisterwebadaptor/
    def unregister_web_adaptor(self, web_adaptor_id):
        token = self.generate_token()

        data = {
            'f': 'json'
        }

        return self.send_request('POST', f'/admin/system/webadaptors/{web_adaptor_id}/unregister', data, token)

    # Unregister all ArcGIS Web Adaptors
    def unregister_web_adaptors(self):
        for web_adaptor in self.get_web_adaptors():
            self.unregister_web_adaptor(web_adaptor['id'])
        
        return {
            'status': 'success'
        }

    # Get the local machine name
    def get_local_machine_name(self):
        token = self.generate_token()

        return self.send_request('GET', '/admin/local?f=json', None, token)['machineName']
    
    def get_machine_info(self, machine_name):
        token = self.generate_token()

        return self.send_request('GET', f'/admin/machines/{machine_name}?f=json', None, token)
    
    # Get the SSL certificate alias of the server machine
    def get_server_ssl_certificate(self, machine_name):
        return self.get_machine_info(machine_name)['webServerCertificateAlias']

    # Returns True if SSL certificate exists in the machine
    # See https://developers.arcgis.com/rest/enterprise-administration/server/certificate/
    def ssl_certificate_exists(self, machine_name, cert_alias, entry_type = 'PrivateKeyEntry'):
        try:
            token = self.generate_token()

            certs = self.send_request('GET', f'/admin/machines/{machine_name}/sslcertificates/{cert_alias}?f=json', None, token)

            return 'entryType' not in certs or certs['entryType'] == entry_type
        except RestServiceError as e:
            if e.code == 404:
                return False

            raise e

    # Import an SSL certificate into the machine
    # See https://developers.arcgis.com/rest/enterprise-administration/server/importrootcertificate/
    def import_root_ssl_certificate(self, machine_name, cert_file, cert_alias):
        token = self.generate_token()

        root_cert = open(cert_file, 'r').read()

        data = {
            'rootCACertificate': root_cert,
            'alias': cert_alias,
            'f': 'json'
        }

        return self.send_request('POST', f'/admin/machines/#{machine_name}/sslcertificates/importRootOrIntermediate', data, token)

    # Import an existing SSL certificate into keystore of the server machine
    # See https://developers.arcgis.com/rest/enterprise-administration/server/importexistingservercertificate/
    def import_server_ssl_certificate(self, machine_name, cert_file, cert_password, cert_alias):
        url = self.server_admin_url + f'/admin/machines/{machine_name}/sslcertificates/importExistingServerCertificate'
        
        token = self.generate_token()

        fields = {
            'certPassword': cert_password,
            'alias': cert_alias,
            'f': 'json'
        }
       
        files = {
            'certFile': cert_file
        }

        return self.post_multipart_form_data(url, fields, files, token)


    # Set the SSL certificate of the server machine
    # See https://developers.arcgis.com/rest/enterprise-administration/server/editmachine/
    def set_server_ssl_certificate(self, machine_name, cert_alias):
        token = self.generate_token()

        machine = self.get_machine_info(machine_name)

        data = {
            'machineName': machine_name,
            'adminURL': machine['adminURL'],
            'webServerMaxHeapSize': machine['webServerMaxHeapSize'],
            'webServerCertificateAlias': cert_alias,
            #'appServerMaxHeapSize': machine['appServerMaxHeapSize'],
            'socMaxHeapSize': machine['socMaxHeapSize'],
            #'OpenEJBPort': machine['ports']['OpenEJBPort'],
            #'JMXPort': machine['ports']['JMXPort'],
            #'NamingPort': machine['ports']['NamingPort'],
            #'DerbyPort': machine['ports']['DerbyPort'],
            'f': 'json'
        }

        return self.send_request('POST', f'/admin/machines/{machine_name}/edit', data, token)

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

    def send_request(self, method, url, data, token, headers = {}):
        try:
            request = urllib.request.Request(self.server_admin_url + url)
            
            request.method = method

            request.add_header('Referer', 'referer')

            if data is not None:
                request.data = urllib.parse.urlencode(data).encode('utf-8')

            if token is not None:
                request.add_header('Authorization', 'Bearer ' + token)

            for header in headers:
                request.add_header(header, headers[header])    

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

    def post_multipart_form_data(self, url, fields, files, token):
        """
        Posts multipart/form-data to a specified URL.

        :param url: The URL to post the data to.
        :param fields: A dictionary of form fields and their values.
        :param files: A dictionary of file fields and their file paths.
        """
        try:
            # Prepare the fields and files for MultipartEncoder
            multipart_fields = fields.copy()
            for field_name, file_path in files.items():
                multipart_fields[field_name] = (os.path.basename(file_path), open(file_path, 'rb'), 'application/octet-stream')

            # Create the MultipartEncoder object
            data = MultipartEncoder(fields=multipart_fields)

            # Set the headers
            headers = {
                'Authorization': 'Bearer ' + token,
                'Content-Type': data.content_type,
                'Referer': 'referer'
            }

            # Post the data
            response = requests.post(url, data=data, headers=headers, verify=False)

            if response.status_code > 200:
                raise RestServiceError(response.status_code, response.text)

            json_response = json.loads(response.text)

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
       
    