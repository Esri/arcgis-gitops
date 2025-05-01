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

# Creates AMIs from deployment EC2 instances and stores the AMI IDs in SSM parameters.

import argparse
import boto3
from datetime import datetime

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='snapshot_deployment.py',
        description='Creates AMIs from deployment EC2 instances and stores the AMI IDs in SSM parameters.')

    parser.add_argument('-s', dest='site_id', help='ArcGIS Enterprise site Id')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment Id')

    args = parser.parse_args()

    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')

    ec2_filters = [{
        'Name': 'tag:ArcGISSiteId',
        'Values': [args.site_id]
    }, {
        'Name': 'tag:ArcGISDeploymentId',
        'Values': [args.deployment_id]
    }, {
        'Name': 'instance-state-name',
        'Values': ['running', 'stopped']
    }]

    ec2_reservations = ec2_client.describe_instances(
        Filters=ec2_filters
    )['Reservations']

    amis_by_role = {}
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S') 

    for reservation in ec2_reservations:
        for instance in reservation['Instances']:
            machine_role = None
            arcgis_version = ''
            operating_system = ''
            for tag in instance['Tags']:
                if tag['Key'] == 'ArcGISMachineRole':
                    machine_role = tag['Value']
                elif tag['Key'] == 'ArcGISVersion':
                    arcgis_version = tag['Value']
                elif tag['Key'] == 'OperatingSystem':
                    operating_system = tag['Value']
            
            if machine_role is None:
                print("Machine role not found for instance '{0}'.".format(instance['InstanceId']))
                continue

            if machine_role not in amis_by_role:
                ami_name  = '{site}-{deployment}-{version}-{role}-{timestamp}'.format(
                    site=args.site_id,
                    deployment=args.deployment_id,
                    version=arcgis_version,
                    role=machine_role,
                    timestamp=timestamp)
                
                ami_description = 'AMI created from {site}/{deployment}/{role} EC2 instance'.format(
                    site=args.site_id,
                    deployment=args.deployment_id,
                    role=machine_role)

                amis_by_role[machine_role] = ec2_client.create_image(
                    InstanceId=instance['InstanceId'],
                    Name=ami_name,
                    Description=ami_description,
                    NoReboot=False,
                    TagSpecifications=[{
                        'ResourceType': 'image',
                        'Tags': [{
                            'Key': 'Name',
                            'Value': ami_name
                        }, {
                            'Key': 'ArcGISSiteId',
                            'Value': args.site_id
                        }, {
                            'Key': 'ArcGISDeploymentId',
                            'Value': args.deployment_id
                        }, {
                            'Key': 'ArcGISMachineRole',
                            'Value': machine_role
                        }, {
                            'Key': 'ArcGISVersion',
                            'Value': arcgis_version
                        }, {
                            'Key': 'OperatingSystem',
                            'Value': operating_system
                        }]
                    }]
                )['ImageId']

                print("AMI Id '{ami_id}' created from instance '{instance}'.".format(
                    ami_id=amis_by_role[machine_role], instance=instance['InstanceId']))
    
    print("Waiting for the AMIs to become available...")
    waiter = ec2_client.get_waiter('image_available')
    waiter.config.max_attempts = 2400 # 10 hours
    waiter.wait(ImageIds=list(amis_by_role.values()))

    # Store AMI Ids in SSM parameters
    for role, ami_id in amis_by_role.items():
        ssm_parameter_name = '/arcgis/{site}/images/{deployment}/{role}'.format(
                site=args.site_id,
                deployment=args.deployment_id,
                role=role)
        
        ssm_parameter_description = 'AMI created from {site}/{deployment}/{role} EC2 instance'.format(
                site=args.site_id,
                deployment=args.deployment_id,
                role=role)
        
        ssm_client.put_parameter(
            Name=ssm_parameter_name,
            Description=ssm_parameter_description,
            Value=ami_id,
            Type='String',
            Overwrite=True,
            Tier='Intelligent-Tiering'
        )

        print("AMI Id '{ami_id}' stored in '{parameter}' SSM parameter.".format(
            ami_id=ami_id, 
            parameter=ssm_parameter_name))
