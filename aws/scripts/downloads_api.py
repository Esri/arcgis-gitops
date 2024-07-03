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

# My Esri Downloads API repository client

import json
import ssl
import urllib.parse
import urllib.request


class DownloadsAPIClient:
    def __init__(self, downloads_service_url='https://downloads.arcgis.com'):
        self.downloads_service_url = downloads_service_url

    # Generates URL for downloading file from the repository
    def generate_url(self, file: str, folder: str, token: str):
        if token is None:
            raise Exception("Repository access credentials are not specified.")

        url = self.downloads_service_url + '/dms/rest/download/secured/' + file
        params = {'folder': folder, 'token': token}
        encoded_params = urllib.parse.urlencode(params)
        full_url = url + '?' + encoded_params

        request = urllib.request.Request(full_url)
        request.add_header('Referer', 'referer')

        response = urllib.request.urlopen(request, context=ssl._create_unverified_context())

        json_response = json.loads(response.read().decode())

        if response.code > 200:
            raise Exception(json_response['message'])

        return json_response['url']
