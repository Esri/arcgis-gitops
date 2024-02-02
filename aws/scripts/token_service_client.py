
# ArcGIS Online token service client

import json
import ssl
import urllib.parse
import urllib.request


class TokenServiceClient:

    def __init__(self, token_service_url='https://www.arcgis.com/sharing/rest/generateToken'):
        self.token_service_url = token_service_url

    # Generates token for the specified username and password.
    def generate_token(self, username: str, password: str, referer='referer', expiration=600):
        request = urllib.request.Request(self.token_service_url)
        request.method = 'POST'

        data = {
            'username': username,
            'password': password,
            'client': 'referer',
            'referer': referer,
            'expiration': str(expiration),
            'f': 'json'
        }

        request.data = urllib.parse.urlencode(data).encode('utf-8')

        response = urllib.request.urlopen(
            request, context=ssl._create_unverified_context())
        json_response = json.loads(response.read().decode())

        if response.code > 200:
            raise Exception(json_response['message'])
        if 'error' in json_response and 'message' in json_response['error']:
            raise Exception(json_response['error']['message'])

        return json_response['token']
