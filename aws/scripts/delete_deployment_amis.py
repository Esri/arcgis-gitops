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

# Deletes AMIs used by the specified deployment and SSM parameters referencing the AMIs.

import argparse
import boto3

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='delete_deployment_amis.py',
        description='Deletes AMIs used by the specified deployment and SSM parameters referencing the AMIs.')

    parser.add_argument('-s', dest='site_id', required=True, help='ArcGIS Enterprise site Id')
    parser.add_argument('-d', dest='deployment_id', required=True, help='ArcGIS Enterprise deployment Id')

    args = parser.parse_args()

    print(f'Deleting AMIs for deployment \"{args.deployment_id}\" in site \"{args.site_id}\"...')

    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')

    # Get the AMIs used by the specified deployment
    images = ec2_client.describe_images(
        Owners=['self'],
        Filters=[
            {
                'Name': 'tag:ArcGISDeploymentId',
                'Values': [args.deployment_id]
            },
            {
                'Name': 'tag:ArcGISSiteId',
                'Values': [args.site_id]
            }
        ],
        MaxResults=1000
    )['Images']

    for image in images:
        image_id = image['ImageId']
        image_name = image['Name']

        # Skip AWS Backup created AMIs
        if image_name.startswith('AwsBackup_'):
            continue

        print(f'Deleting AMI {image_id} ({image_name})...')
        
        ec2_client.deregister_image(ImageId=image_id)

        # Delete the associated snapshots
        for block_device in image['BlockDeviceMappings']:
            if 'Ebs' in block_device:
                snapshot_id = block_device['Ebs']['SnapshotId']
                print(f'Deleting snapshot {snapshot_id}...')
                ec2_client.delete_snapshot(SnapshotId=snapshot_id)

    ssm_parameters = ssm_client.describe_parameters(
        ParameterFilters=[
            {
                'Key': 'Name',
                'Option': 'BeginsWith',
                'Values': [
                    f'/arcgis/{args.site_id}/images/{args.deployment_id}/'
                ]
            }
        ]
    )['Parameters']

    for parameter in ssm_parameters:
        parameter_name = parameter['Name']
        print(f'Deleting SSM parameter {parameter_name}...')
        ssm_client.delete_parameter(Name=parameter_name)

    print('Done.')