# Copyright 2024-2026 Esri
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

# Waits for target SSM managed EC2 instances to become available.

import argparse
import boto3
import ssm_utils

# Timeouts in seconds
WAIT_TIMEOUT = 600

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ssm_wait_for_target_instances.py',
        description='Waits for target SSM managed EC2 instances to become available.')

    parser.add_argument('-s', dest='enterprise_id', help='ArcGIS Enterprise ID')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment ID')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')

    args = parser.parse_args()

    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')

    ec2_filters = [{
        'Name': 'tag:ArcGISEnterpriseID',
        'Values': [args.enterprise_id]
    }, {
        'Name': 'tag:ArcGISDeploymentID',
        'Values': [args.deployment_id]
    }, {
        'Name': 'tag:ArcGISMachineRole',
        'Values': args.machine_roles.split(',')
    }, {
        'Name': 'instance-state-name',
        'Values': ['pending', 'running']
    }]

    ssm_filters = [{
        'Key': 'tag:ArcGISEnterpriseID',
        'Values': [args.enterprise_id]
    }, {
        'Key': 'tag:ArcGISDeploymentID',
        'Values': [args.deployment_id]
    }, {
        'Key': 'tag:ArcGISMachineRole',
        'Values': args.machine_roles.split(',')
    }]

    if not ssm_utils.wait_for_target_instances(ec2_client, ssm_client, ec2_filters, ssm_filters, WAIT_TIMEOUT):
        exit(1)

    exit(0)
