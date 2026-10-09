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

# Runs AWS-ConfigureAWSPackage SSM command on all EC2 instances in the specified roles,
# waits for all the command invocations to complete, and
# retrieves from S3 and prints outputs of the command invocations.

import argparse
import re
import time
import boto3
import ssm_utils

# Timeouts in seconds
WAIT_TIMEOUT = 600
SEND_TIMEOUT = 600 
EXECUTION_TIMEOUT = 1800
INSTALL_ATTEMPTS = 4
RETRY_DELAY = 30
MSI_BUSY = re.compile(r'\b(?:exit|error|return|response)\s+code\s*[:=]?\s*1618\b', re.IGNORECASE)


def wait_for_package_invocations(ssm_client, command_id):
    deadline = time.monotonic() + EXECUTION_TIMEOUT
    paginator = ssm_client.get_paginator('list_command_invocations')
    while time.monotonic() < deadline:
        invocations = [invocation
                       for page in paginator.paginate(CommandId=command_id, Details=True)
                       for invocation in page['CommandInvocations']]
        if invocations and all(invocation['Status'] not in
                               ('Pending', 'InProgress', 'Delayed', 'Cancelling')
                               for invocation in invocations):
            return invocations
        time.sleep(ssm_utils.SLEEP_TIME)
    print('Package command invocations timed out.')
    return []


def installer_is_busy(s3_client, s3_bucket, deployment_id, command_id, invocation):
    for plugin in invocation.get('CommandPlugins', []):
        if plugin.get('ResponseCode') == 1618 or MSI_BUSY.search(plugin.get('Output', '')):
            return True
    prefix = '{0}/{1}/{2}/'.format(deployment_id, command_id, invocation['InstanceId'])
    objects = s3_client.list_objects_v2(Bucket=s3_bucket, Prefix=prefix, MaxKeys=1000)
    for item in objects.get('Contents', []):
        if item['Key'].rsplit('/', 1)[-1] not in ('stdout', 'stderr'):
            continue
        body = s3_client.get_object(Bucket=s3_bucket, Key=item['Key'])['Body']
        try:
            output = body.read().decode('UTF-8', 'ignore')
        finally:
            body.close()
        if MSI_BUSY.search(output):
            return True
    return False


def install_package(ssm_client, s3_client, ssm_filters, package, version, s3_bucket, deployment_id):
    targets = {'Targets': ssm_filters}
    for attempt in range(INSTALL_ATTEMPTS):
        command_id = ssm_client.send_command(
            **targets,
            DocumentName='AWS-ConfigureAWSPackage',
            TimeoutSeconds=SEND_TIMEOUT,
            Comment='Installs AWS package on EC2 instances.',
            Parameters={'action': ['Install'], 'name': [package], 'version': [version]},
            OutputS3BucketName=s3_bucket,
            OutputS3KeyPrefix=deployment_id
        )['Command']['CommandId']
        invocations = wait_for_package_invocations(ssm_client, command_id)
        ssm_utils.print_command_output(s3_client, deployment_id, command_id, s3_bucket)
        if not invocations:
            return False
        failures = [invocation for invocation in invocations if invocation['Status'] != 'Success']
        if not failures:
            return True
        if attempt == INSTALL_ATTEMPTS - 1 or any(
                invocation['Status'] != 'Failed' or not installer_is_busy(
                    s3_client, s3_bucket, deployment_id, command_id, invocation)
                for invocation in failures):
            return False
        delay = RETRY_DELAY * (2 ** attempt)
        targets = {'InstanceIds': [invocation['InstanceId'] for invocation in failures]}
        print('MSI installer busy (1618); retrying {0} in {1} seconds (attempt {2}/{3}).'
              .format(targets['InstanceIds'], delay, attempt + 2, INSTALL_ATTEMPTS))
        time.sleep(delay)
    return False

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ssm_package.py',
        description='Runs AWS-ConfigureAWSPackage SSM command on EC2 instances in a deployment with specified roles.')

    parser.add_argument('-s', dest='enterprise_id', help='ArcGIS Enterprise ID')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment ID')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')
    parser.add_argument('-p', dest='package', help='AWS Package Manager package name')
    parser.add_argument('-v', dest='version', default='', help='AWS Package Manager package version')
    parser.add_argument('-b', dest='s3_bucket', help='Output S3 bucket')

    args = parser.parse_args()

    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')
    s3_client = boto3.client('s3')

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

    success = install_package(ssm_client, s3_client, ssm_filters, args.package,
                              args.version, args.s3_bucket, args.deployment_id)
    exit(0 if success else 1)
