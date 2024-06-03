#!/usr/bin/python

from __future__ import (absolute_import, division, print_function)

__metaclass__ = type

DOCUMENTATION = r'''
---
module: s3files

short_description: Dowloads files from S3 bucket to local directories

version_added: "0.1.0"

description: Downloads software setups and patches specified in the manifest file from S3 bucket to local software repository directories.

requirements:
    - boto3 python module
    - AWS credentials configured on the host

options:
    manifest:
        description: Path to the manifest file that contains the list of files to download from S3 bucket.
        required: true
        type: str
'''

EXAMPLES = r'''
- name: Download setups from private S3 repository
  s3files:
    manifest: '/opt/software/arcgis-server-s3files-11.2.json'
'''

RETURN = r'''
output:
    description: The output messages that the module generates.
    type: list
    returned: always
    elements: str
'''

import traceback
import hashlib
import fnmatch
import json
import os

from pathlib import Path
from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.basic import missing_required_lib

BOTO3_IMP_ERR = None

try:
    import boto3
    HAS_BOTO3 = True
except:
    HAS_BOTO3 = False
    BOTO3_IMP_ERR = traceback.format_exc()

def validate_sha256(filepath: str, sha256: str):
    """
    Validates the SHA-256 hash of the file.
    """

    actual_sha256 = None
    if os.path.exists(filepath):
        with open(filepath, 'rb') as f:
            sha256_hash = hashlib.sha256()
            sha256_hash.update(f.read())
            actual_sha256 = sha256_hash.hexdigest().lower()
    return actual_sha256 and actual_sha256 == sha256


def download_s3_files(manifest: str):
    """
    Downloads files specified in the manifest file from S3 bucket to local directories.
    """

    with open(manifest, 'r') as f:
        data = json.load(f)

    bucket_name = data['arcgis']['repository']['server']['s3bucket']
    region = data['arcgis']['repository']['server']['region']

    s3_client = boto3.client('s3', region_name=region)

    if 'arcgis' not in data or 'repository' not in data['arcgis']:
        raise Exception('JSON file format is invalid.')
    
    local_archives = data['arcgis']['repository']['local_archives']
    local_patches = data['arcgis']['repository']['local_patches']
    patch_notification = data['arcgis']['repository']['patch_notification']
    patchs_subfolder = patch_notification['subfolder']
    patches = patch_notification['patches']
    
    # Create local archives and patches directories if they doe not exist.
    archives_path = Path(local_archives)
    archives_path.mkdir(parents=True, exist_ok=True)

    patches_path = Path(local_patches)
    patches_path.mkdir(parents=True, exist_ok=True)

    output = []
    
    changed = False

    # Download files

    files = data['arcgis']['repository']['files']

    for filename, props in files.items():
        subfolder = props['subfolder'] if 'subfolder' in props else None
        # sha256 = props['sha256'].lower() if 'sha256' in props else None
        s3_key = "{0}/{1}".format(subfolder, filename) if subfolder else filename
        filepath = os.path.join(local_archives, filename)
        
        try:
            if os.path.exists(filepath):
                output.append("Local file '{0}' already exists.".format(filepath))
            else:
                s3_client.download_file(bucket_name, s3_key, filepath)
                changed = True
                output.append("File '{0}' downloaded successfully.".format(s3_key))
        except Exception as e:
            raise Exception("Failed to download file '{0}' from S3 bucket '{1}'. {2}".format(s3_key, bucket_name, str(e)))
        
    # Download patches

    keys = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=patchs_subfolder)

    if 'Contents' in keys:
        for key in keys['Contents']:
            filename = os.path.basename(key['Key'])
            if any(fnmatch.fnmatch(filename, patch) for patch in patches):
                filepath = os.path.join(local_patches, filename)

                try:
                    if os.path.exists(filepath):
                        output.append("Local file '{0}' already exists.".format(filepath))
                    else:
                        s3_client.download_file(bucket_name, key['Key'], filepath)
                        changed = True
                        output.append("Patch '{0}' downloaded successfully.".format(key['Key']))
                except Exception as e:
                    raise Exception("Failed to download file '{0}' from S3 bucket '{1}'. {2}".format(key['Key'], bucket_name, str(e)))

    return changed, output


def run_module():
    module_args = dict(
        manifest=dict(type='str', required=True)
    )

    result = dict(
        changed=False,
        output=''
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True
    )

    if not HAS_BOTO3:
        module.fail_json(msg=missing_required_lib("boto3"),
                         exception=BOTO3_IMP_ERR)

    if module.check_mode:
        module.exit_json(**result)

    try:
        result['changed'], result['output'] = download_s3_files(module.params['manifest'])

        module.exit_json(**result)
    except Exception as e:
        module.fail_json(msg=str(e), **result)


def main():
    run_module()


if __name__ == '__main__':
    main()