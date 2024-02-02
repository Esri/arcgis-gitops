# Copies files from local file system, public URLs, and, My Esri repository to S3 bucket.


import argparse
import hashlib
import json
import os
import sys
import tempfile
import urllib

import boto3
from downloads_api import DownloadsAPIClient
from token_service_client import TokenServiceClient

def s3_object_sha256(s3_bucket, s3_key):
    try:
        sha256 = s3_bucket.Object(s3_key).metadata['sha256']
        print("S3 object SHA256=" + sha256)   
        return sha256.lower() if sha256 else None
    except Exception as e:
        return None
    
def copy_file(url: str, path: str, filename: str, subfolder: str, s3_bucket, sha256=None):
    if subfolder is None:
        s3_key = filename        
    else:
        s3_key = "{0}/{1}".format(subfolder, filename)

    filepath = os.path.join(tempfile.gettempdir(), filename)
    
    try:
        if sha256 and sha256 == s3_object_sha256(s3_bucket, s3_key):
            print("Object '{0}' already exists in the S3 bucket.".format(s3_key))
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
            
            extra_args = {'Metadata': {'sha256': sha256}}
        

        print("Uploading '{0}' to '{1}'...".format(filename, s3_key))

        s3_bucket.upload_file(filepath, s3_key, ExtraArgs=extra_args)

        print("File '{0}' copied.".format(filename))
    finally:
        if not path and os.path.exists(filepath):
            os.remove(filepath)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='s3_copy_files.py',
        description='Copies files from local file system, public URLs, and, My Esri repository to S3 bucket.')

    parser.add_argument('-b', dest='bucket_name',
                        help='S3 bucket name')
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

    if args.password:
        password = args.password
    elif 'ARCGIS_ONLINE_PASSWORD' in os.environ:
        password = os.environ['ARCGIS_ONLINE_PASSWORD']

    ssm_client = boto3.client('ssm')
    s3 = boto3.resource('s3')

    s3_bucket = s3.Bucket(args.bucket_name)

    with open(args.files, 'r') as f:
        data = json.load(f)

    if 'arcgis' not in data or 'repository' not in data['arcgis']:
        print('JSON file format is invalid.')
        sys.exit(0)

    repository_url = None
    token_service_url = None

    if 'server' in data['arcgis']['repository']:
        downloads_api = DownloadsAPIClient(
            data['arcgis']['repository']['server']['url'])
        token_service = TokenServiceClient(
            data['arcgis']['repository']['server']['token_service_url'])
    else:
        downloads_api = DownloadsAPIClient()
        token_service = TokenServiceClient()

    files = data['arcgis']['repository']['files']

    print("Copying files to '{0}' S3 bucket...".format(args.bucket_name))

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
            copy_file(url, path, filename, subfolder, s3_bucket, sha256)
        except Exception as e1:
            print(e1)
            print("Retrying copy of '{0}'...".format(filename))

            try:
                copy_file(url, path, filename, subfolder, s3_bucket, sha256)
            except Exception as e2:
                print(e2)
                sys.exit(1)

    print("{0} files processed.".format(len(files)))
