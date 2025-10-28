# Copyright 2025 Esri
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

# Copies files from local file system, public URLs, My Esri, and ArcGIS patch repositories to Azure Blob Storage.

import argparse
import hashlib
import json
import os
import sys
import tempfile
import urllib
import fnmatch

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from downloads_api import DownloadsAPIClient
from token_service_client import TokenServiceClient
from patch_notification import PatchNotification

def azure_blob_sha256(container_client, blob_name):
    try:
        blob_client = container_client.get_blob_client(blob_name)
        sha256 = blob_client.get_blob_properties().metadata['sha256']
        print("Azure Blob SHA256=" + sha256)
        return sha256.lower() if sha256 else None
    except Exception as e:
        return None


def copy_file(url: str, path: str, filename: str, subfolder: str, container_client, sha256=None):
    if subfolder is None:
        blob_name = filename
    else:
        blob_name = "{0}/{1}".format(subfolder, filename)

    filepath = os.path.join(tempfile.gettempdir(), filename)
    
    try:
        if sha256 and sha256 == azure_blob_sha256(container_client, blob_name):
            print("Object '{0}' already exists in the Azure Blob Storage.".format(blob_name))
            return

        if path:
            filepath = path
        else:
            print("Downloading '{0}' from '{1}'...".format(filename, url))
            urllib.request.urlretrieve(url, filepath)

        extra_args = {}

        if sha256:
            print("Validating SHA256 hash...")
            
            with open(filepath, 'rb') as f:
                sha256_hash = hashlib.sha256()
                sha256_hash.update(f.read())
                print("SHA-256=" + sha256_hash.hexdigest())
                if sha256_hash.hexdigest().lower() != sha256:
                    raise Exception(
                        "SHA-256 hash validation of '{0}' failed.".format(filename))
            
            extra_args = {'sha256': sha256}
        
        print("Uploading '{0}' to '{1}'...".format(filename, blob_name))

        with open(filepath, 'rb') as data:
            blob_client = container_client.get_blob_client(blob_name)
            
            blob_client.upload_blob(data, overwrite=True)

            properties = blob_client.get_blob_properties()
            blob_metadata = properties.metadata
            blob_metadata.update(extra_args)
            blob_client.set_blob_metadata(metadata=blob_metadata)

        print("File '{0}' copied.".format(filename))
    finally:
        if not path and os.path.exists(filepath):
            os.remove(filepath)


def copy_files(data, container_client, username, password):
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
        path = props['path'] if 'path' in props else None
        url = props['url'] if 'url' in props else None

        if not path and not url:
            # Generate Downloads API URL
            token = token_service.generate_token(username, password)
            url = downloads_api.generate_url(filename, subfolder, token)

        try:
            copy_file(url, path, filename, subfolder, container_client, sha256)
        except Exception as e1:
            print(e1)
            print("Retrying copy of '{0}'...".format(filename))

            try:
                copy_file(url, path, filename, subfolder, container_client, sha256)
            except Exception as e2:
                print(e2)
                sys.exit(1)

    print("{0} files copied.".format(len(files)))

def matches_pattern(filename, patterns):
    for pattern in patterns:
        if len(fnmatch.filter([filename], pattern)) > 0:
            return True
    return False

# 
def copy_patches(data, container_client):
    if 'patch_notification' not in data['arcgis']['repository']:
        return
    
    patch_notification = data['arcgis']['repository']['patch_notification']

    subfolder = patch_notification['subfolder']
    patterns = patch_notification['patches']

    if 'url' in patch_notification and patch_notification['url'] != '':
        patches_repository = PatchNotification(patch_notification['url'])
    else:
        patches_repository = PatchNotification()

    patches = patches_repository.get_patches(patch_notification['products'], 
                                             patch_notification['versions'])

    patches_processed = 0

    for patch in patches:
        print("Processing patch '{0}'...".format(patch['Name']))
        patch_sha = {}
        
        for file_sha in patch['SHA256sums']:
            tokens = file_sha.split(':')
            patch_sha[tokens[0]] = tokens[1]

        for url in patch['PatchFiles']:
            filename = os.path.basename(url)

            if not matches_pattern(filename, patterns):
                continue

            sha256 = patch_sha[filename].lower() if filename in patch_sha else None
           
            copy_file(url, None, filename, subfolder, container_client, sha256)

            patches_processed += 1

    print("{0} patches copied.".format(patches_processed))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='az_copy_files.py',
        description='Copies files from local file system, public URLs, and, My Esri, and ArcGIS patch repositories to Azure Blob Storage.')

    parser.add_argument('-a', dest='storage_account_blob_endpoint',
                        help='Azure Storage Account Blob Endpoint')
    parser.add_argument('-c', dest='container_name',
                        help='Azure Blob Storage Container Name')
    parser.add_argument('-u', dest='username',
                        required=False, help='My Esri user name')
    parser.add_argument('-p', dest='password', required=False,
                        help='My Esri user password')
    parser.add_argument('-f', dest='files', required=True,
                        help='Index JSON file path')

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

    # Acquire a credential object
    credential = DefaultAzureCredential()

    blob_service_client = BlobServiceClient(
        account_url=args.storage_account_blob_endpoint,
        credential=credential)

    container_client = blob_service_client.get_container_client(args.container_name)

    with open(args.files, 'r') as f:
        data = json.load(f)

    if 'arcgis' not in data or 'repository' not in data['arcgis']:
        print('JSON file format is invalid.')
        sys.exit(0)

    print("Copying files to '{0}' Azure Blob Storage container...".format(args.container_name))

    copy_files(data, container_client, username, password)

    copy_patches(data, container_client)
