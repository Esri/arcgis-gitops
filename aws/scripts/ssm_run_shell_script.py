# Copyright 2025-2026 Esri
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

# The script runs a shell script on EC2 instances of a deployment.
# 
# The script retrieves the script input parameters from the JSON_ATTRIBUTES environment variable
# and puts them into SecureString SSM parameter specified by json_attributes_parameter command line argument.
# Placeholder <json_attributes_parameter> in the scrip is replaced with the actual parameter name.
# To execute the script it runs the selected shell or PowerShell SSM document on EC2 instances of the deployment
# in the specified machine roles, waits for all the command invocations to complete, 
# retrieves from S3 and prints outputs of the command invocations.

import os
import base64
import argparse
import boto3
import ssm_utils

WAIT_TIMEOUT = 600
SEND_TIMEOUT = 600 # seconds

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ssm_run_shell_script.py',
        description='Runs  AWS-RunShellScript SSM command on EC2 instances of a deployment.')

    parser.add_argument('-s', dest='enterprise_id', required=True, help='ArcGIS Enterprise ID')
    parser.add_argument('-d', dest='deployment_id', required=True, help='ArcGIS Enterprise deployment ID')
    parser.add_argument('-m', dest='machine_roles', required=True, help='Machine roles')
    parser.add_argument('-j', dest='json_attributes_parameter', default=None, help='SSM parameter name of the script input parameters')
    parser.add_argument('-b', dest='s3_bucket', required=True, help='Output S3 bucket')
    parser.add_argument('-e', dest='execution_timeout', default="3600", help='Execution timeout (seconds)')
    parser.add_argument('-f', dest='script_file', required=True, help='Script file path')
    parser.add_argument('--document-name', choices=['AWS-RunShellScript', 'AWS-RunPowerShellScript'],
                        default='AWS-RunShellScript', help='SSM document matching the target platform')

    args = parser.parse_args()

    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')
    s3_client = boto3.client('s3')

    commands = []
    with open(args.script_file, 'r', encoding='utf-8') as file:
        for line in file:
            if '<json_attributes_parameter>' in line:
                if not args.json_attributes_parameter:
                    parser.error('The script requires -j for <json_attributes_parameter>.')
                line = line.replace('<json_attributes_parameter>', args.json_attributes_parameter)
            line = line.replace('<aws_region>', ssm_client.meta.region_name)
            commands.append(line.rstrip('\r\n'))

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

    # Put JSON attributes to SSM parameter if JSON_ATTRIBUTES env variable is defined
    if 'JSON_ATTRIBUTES' in os.environ and args.json_attributes_parameter:
        jsonAttributes = base64.b64decode(os.environ['JSON_ATTRIBUTES']).decode('utf-8')
    
        print("Creating SecureString SSM parameter {0}...".format(args.json_attributes_parameter))

        ssm_client.put_parameter(
            Name=args.json_attributes_parameter,
            Description='Script input parameters in JSON format',
            Value=jsonAttributes,
            Type='SecureString',
            Tags=[
                {
                    'Key': 'ArcGISEnterpriseID',
                    'Value': args.enterprise_id
                },
            ],
            Tier='Intelligent-Tiering'
        )

    try:
        command_id = ssm_client.send_command(
            Targets=ssm_filters,
            DocumentName=args.document_name,
            TimeoutSeconds=SEND_TIMEOUT,
            Comment='Runs shell script.',
            Parameters={
                'commands': commands,
                'executionTimeout': [args.execution_timeout]
            },
            OutputS3BucketName=args.s3_bucket,
            OutputS3KeyPrefix=args.deployment_id
        )['Command']['CommandId']

        status = ssm_utils.wait_for_command_invocations(ssm_client, command_id, int(args.execution_timeout))
        ssm_utils.print_command_output(s3_client, args.deployment_id, command_id, args.s3_bucket)
    finally:
        if 'JSON_ATTRIBUTES' in os.environ and args.json_attributes_parameter:
            print("Deleting SecureString SSM parameter {0}...".format(args.json_attributes_parameter))
            ssm_client.delete_parameter(Name=args.json_attributes_parameter)

    exit(0 if status == 'Success' else 1)
