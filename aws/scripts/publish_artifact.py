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

# Retrieves AMI Id from packer-manifest.json file and saves in SSM parameter.

import argparse
import json
import boto3

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='publish_artifact.py',
        description='Retrieves AMI Id from packer-manifest.json file and saves in SSM parameter.')

    parser.add_argument('-p', dest='parameter', help='SSM parameter name')
    parser.add_argument('-f', dest='manifest', help='packer-manifest.json file path')
    parser.add_argument('-r', dest='packer_run_uuid', help='Packer run UUID')

    args = parser.parse_args()

    with open(args.manifest, encoding="utf-8") as fp:
        manifest = json.load(fp)

    ami_id = None
    
    for build in manifest['builds']:
        if build['packer_run_uuid'] == args.packer_run_uuid:
            ami_id = build['artifact_id'].split(':')[1]
            ami_description = build['custom_data']['ami_description']
    
    if ami_id is None:
        print("The packer run UUID not found in {0} manifest file.".format(args.manifest))
        exit(1)

    ssm_client = boto3.client('ssm')

    ssm_client.put_parameter(
        Name=args.parameter,
        Description=ami_description,
        Value=ami_id,
        Type='String',
        Overwrite=True,
        Tier='Intelligent-Tiering'
    )

    print("AMI Id '{0}' stored in '{1}' SSM parameter.".format(ami_id, args.parameter))