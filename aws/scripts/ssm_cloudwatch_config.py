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

# Runs AmazonCloudWatch-ManageAgent SSM command on all EC2 instances in a deployment,
# waits for all the command invocations to complete, and
# retrieves from S3 and prints outputs of the command invocations.

import argparse
import sys
from time import monotonic, sleep
import boto3
from botocore.exceptions import BotoCoreError, ClientError
import ssm_utils
from ssm_run_windows_infrastructure import TERMINAL, replay

# Timeouts in seconds
WAIT_TIMEOUT = 600
SEND_TIMEOUT = 600
EXECUTION_TIMEOUT = 600
MAX_INSTANCE_IDS = 50
TERMINAL_DETAILS = {
    'Delivery Timed Out', 'Execution Timed Out', 'Undeliverable', 'Terminated',
    'Invalid Platform', 'Access Denied',
}
NON_WINDOWS_STEPS = {'ControlCloudWatchAgentLinux', 'ControlCloudWatchAgentMacOS'}
SSM_ERROR_SEPARATOR = '\n----------ERROR-------\n'


def resolve_online_targets(ec2, ssm, ec2_filters, ssm_filters):
    deadline = monotonic() + WAIT_TIMEOUT
    while True:
        targets = {
            instance['InstanceId']
            for page in ec2.get_paginator('describe_instances').paginate(Filters=ec2_filters)
            for reservation in page['Reservations']
            for instance in reservation['Instances']
        }
        if len(targets) > MAX_INSTANCE_IDS:
            print(f"Found {len(targets)} target instances; SSM allows at most "
                  f"{MAX_INSTANCE_IDS} explicit IDs. No command sent.", file=sys.stderr, flush=True)
            return []
        online = {
            node['InstanceId']
            for page in ssm.get_paginator('describe_instance_information').paginate(Filters=ssm_filters)
            for node in page['InstanceInformationList']
            if node['PingStatus'] == 'Online'
        } if targets else set()
        missing = targets - online
        print(f"{len(targets) - len(missing)} of {len(targets)} target instances are online.", flush=True)
        if targets and not missing:
            return sorted(targets)
        remaining = deadline - monotonic()
        if remaining <= 0:
            detail = f"Target instances not online in SSM: {', '.join(sorted(missing))}." if targets else (
                "No pending or running instances match the deployment tags.")
            print(f"{detail} No command sent.", file=sys.stderr, flush=True)
            return []
        sleep(min(10, remaining))


def is_terminal(invocation):
    return invocation['Status'] in TERMINAL or invocation.get('StatusDetails') in TERMINAL_DETAILS


def error_code(exc):
    return exc.response['Error'].get('Code', type(exc).__name__) if isinstance(exc, ClientError) else (
        type(exc).__name__)


def collect_apply_output(ssm, s3, command_id, instance_ids, bucket, deployment_id):
    command_label = f"[AWS CloudWatch agent {command_id}]"
    print(f"{command_label} Submitted to: {', '.join(instance_ids)}", flush=True)
    expected = set(instance_ids)
    observed = {}
    unexpected = set()
    poll_failed = False
    deadline = monotonic() + EXECUTION_TIMEOUT
    try:
        paginator = ssm.get_paginator('list_command_invocations')
        while True:
            for page in paginator.paginate(CommandId=command_id, Details=True):
                for invocation in page['CommandInvocations']:
                    instance = invocation['InstanceId']
                    if instance not in expected:
                        unexpected.add(instance)
                        continue
                    # A later eventually consistent page must not replace a terminal result with a pending one.
                    if instance not in observed or is_terminal(invocation) or not is_terminal(observed[instance]):
                        observed[instance] = invocation
            if expected == observed.keys() and all(map(is_terminal, observed.values())):
                break
            remaining = deadline - monotonic()
            if remaining <= 0:
                print(f"{command_label} Wait timed out; check SSM before retrying.", file=sys.stderr, flush=True)
                break
            sleep(min(5, remaining))
    except (BotoCoreError, ClientError) as exc:
        print(f"{command_label} Could not poll SSM ({error_code(exc)}); check SSM before retrying.",
              file=sys.stderr, flush=True)
        poll_failed = True

    missing = expected - observed.keys()
    unfinished = {instance for instance, invocation in observed.items() if not is_terminal(invocation)}
    for ids, description in ((missing, 'No invocation found for'), (unfinished, 'Invocation still unfinished for'),
                             (unexpected, 'Unexpected invocation for')):
        if ids:
            print(f"{command_label} {description}: {', '.join(sorted(ids))}.", file=sys.stderr, flush=True)
    succeeded = not (poll_failed or missing or unfinished or unexpected)
    for instance in instance_ids:
        if instance not in observed:
            continue
        invocation = observed[instance]
        label = f"[AWS CloudWatch agent {instance} {command_id}]"
        detail = invocation.get('StatusDetails') or invocation['Status']
        print(f"{label} {detail}", flush=True)
        succeeded = succeeded and invocation['Status'] == 'Success' and detail == 'Success'
        # The cross-platform document can report skipped Linux/macOS steps as Success.
        plugins = [plugin for plugin in invocation.get('CommandPlugins', [])
                   if plugin.get('Name') not in NON_WINDOWS_STEPS]
        if invocation['Status'] == 'Success' and not plugins:
            print(f"{label} No plugin results returned for a successful invocation.", file=sys.stderr, flush=True)
            succeeded = False
        prefix = f"{deployment_id}/{command_id}/{instance}/"
        for plugin in plugins or [{}]:
            step = plugin.get('Name')
            code = plugin.get('ResponseCode')
            if plugin:
                print(f"{label} {step or 'Unnamed plugin'}: {plugin.get('StatusDetails') or plugin.get('Status', 'Unknown')} "
                      f"(exit {code if code is not None else 'unavailable'})", flush=True)
                succeeded = succeeded and plugin.get('Status') == 'Success' and code == 0
            # SSM can return URLs for empty streams. Use the agent's combined
            # output only as evidence of which streams are nonempty, never as log text.
            stdout, _, stderr = (plugin.get('Output') or '').replace('\r\n', '\n').partition(SSM_ERROR_SEPARATOR)
            expected_streams = {stream for stream, preview in (('stdout', stdout), ('stderr', stderr)) if preview}
            try:
                collected = replay(s3, bucket, prefix, label, {}, step_name=step,
                                   expected_streams=expected_streams)
                succeeded = succeeded and collected
            except (BotoCoreError, ClientError, OSError) as exc:
                print(f"{label} Could not retrieve stdout/stderr for {step or 'invocation'} "
                      f"from s3://{bucket}/{prefix} ({error_code(exc)}).", file=sys.stderr, flush=True)
                succeeded = False
    return 0 if succeeded else 1

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ssm_cloudwatch_config.py',
        description='Runs AmazonCloudWatch-ManageAgent SSM command on all EC2 instances in a deployment.')

    parser.add_argument('-s', dest='enterprise_id', help='ArcGIS Enterprise ID')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment ID')
    parser.add_argument('-p', dest='parameter', help='SSM parameter name with CloudWatch agent configuration JSON')
    parser.add_argument('-b', dest='s3_bucket', help='Output S3 bucket')
    parser.add_argument('--apply-output', action='store_true', help='Collect both streams from all invocations')

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
        'Name': 'instance-state-name',
        'Values': ['pending', 'running']
    }]

    ssm_filters = [{
        'Key': 'tag:ArcGISEnterpriseID',
        'Values': [args.enterprise_id]
    }, {
        'Key': 'tag:ArcGISDeploymentID',
        'Values': [args.deployment_id]
    }]

    if args.apply_output:
        instance_ids = resolve_online_targets(ec2_client, ssm_client, ec2_filters, ssm_filters)
        if not instance_ids:
            sys.exit(1)
        targeting = {'InstanceIds': instance_ids}
    else:
        if not ssm_utils.wait_for_target_instances(ec2_client, ssm_client, ec2_filters, ssm_filters, WAIT_TIMEOUT):
            sys.exit(1)
        targeting = {'Targets': ssm_filters}

    command = ssm_client.send_command(
        **targeting,
        DocumentName='AmazonCloudWatch-ManageAgent',
        TimeoutSeconds=SEND_TIMEOUT,
        Comment='Installs AWS package on EC2 instances.',
        Parameters={
            'action': ['configure'],
            'optionalConfigurationSource': ['ssm'],
            'optionalConfigurationLocation': [args.parameter]
        },
        OutputS3BucketName=args.s3_bucket,
        OutputS3KeyPrefix=args.deployment_id
    )['Command']
    command_id = command['CommandId']

    if args.apply_output:
        sys.exit(collect_apply_output(ssm_client, s3_client, command_id, instance_ids,
                                      args.s3_bucket, args.deployment_id))

    status = ssm_utils.wait_for_command_invocations(ssm_client, command_id, EXECUTION_TIMEOUT)

    ssm_utils.print_command_output(s3_client, args.deployment_id, command_id, args.s3_bucket)

    exit(0 if status == 'Success' else 1)
