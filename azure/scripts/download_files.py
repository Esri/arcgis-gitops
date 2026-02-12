# Copyright 2026 Esri
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

# Downloads files from public URLs and My Esri to local filesystem.

import argparse
import hashlib
import json
import os
import sys
import urllib

from downloads_api import DownloadsAPIClient
from token_service_client import TokenServiceClient

MAX_CONCURRENCY = 8

def download_file(url: str, filename: str, download_directory: str, sha256=None):
    filepath = os.path.join(download_directory, filename)
    
    print("Downloading '{0}' from '{1}'...".format(filename, url))
    urllib.request.urlretrieve(url, filepath)

    if sha256:
        print("Validating SHA256 hash...")
        
        with open(filepath, 'rb') as f:
            sha256_hash = hashlib.sha256()
            sha256_hash.update(f.read())
            print("SHA-256=" + sha256_hash.hexdigest())
            if sha256_hash.hexdigest().lower() != sha256:
                raise Exception(
                    "SHA-256 hash validation of '{0}' failed.".format(filename))
    
    print("File '{0}' downloaded.".format(filename))


def download_files(data, download_directory, username, password):
    print("Downloading files to '{0}'...".format(download_directory))
    
    if 'server' in data['arcgis']['repository'] and \
       'url' in data['arcgis']['repository']['server']:
        downloads_api = DownloadsAPIClient(
            data['arcgis']['repository']['server']['url'])
    else:
        downloads_api = DownloadsAPIClient()
    
    if 'server' in data['arcgis']['repository'] and \
       'token_service_url' in data['arcgis']['repository']['server']:
        token_service = TokenServiceClient(
            data['arcgis']['repository']['server']['token_service_url'])
    else:
        token_service = TokenServiceClient()

    files = data['arcgis']['repository']['files']

    for filename, props in files.items():
        subfolder = props['subfolder'] if 'subfolder' in props else None
        sha256 = props['sha256'].lower() if 'sha256' in props else None
        url = props['url'] if 'url' in props else None

        if not url:
            # Generate Downloads API URL
            token = token_service.generate_token(username, password)
            url = downloads_api.generate_url(filename, subfolder, token)

        try:
            download_file(url, filename, download_directory, sha256)
        except Exception as e1:
            print(e1)
            print("Retrying download of '{0}'...".format(filename))

            try:
                download_file(url, filename, download_directory, sha256)
            except Exception as e2:
                print(e2)
                sys.exit(1)

    print("{0} files downloaded.".format(len(files)))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='download_files.py',
        description='Downloads files from public URLs and My Esri to local filesystem.')

    parser.add_argument('-u', dest='username', required=False,
                        help='My Esri user name')
    parser.add_argument('-p', dest='password', required=False,
                        help='My Esri user password')
    parser.add_argument('-f', dest='files', required=True,
                        help='Index JSON file path')
    parser.add_argument('-d', dest='download_directory', required=False,
                        help='Directory to download files to')

    args = parser.parse_args()

    if args.username:
        username = args.username
    elif 'ARCGIS_ONLINE_USERNAME' in os.environ:
        username = os.environ['ARCGIS_ONLINE_USERNAME']
    else:
        username = None

    if args.password:
        password = args.password
    elif 'ARCGIS_ONLINE_PASSWORD' in os.environ:
        password = os.environ['ARCGIS_ONLINE_PASSWORD']
    else:
        password = None

    with open(args.files, 'r') as f:
        data = json.load(f)

    if 'arcgis' not in data or 'repository' not in data['arcgis']:
        print('JSON file format is invalid.')
        sys.exit(0)

    if args.download_directory:
        download_directory = args.download_directory
    else:
        download_directory = data['arcgis']['repository']['local_archives']

    download_files(data, download_directory, username, password)
