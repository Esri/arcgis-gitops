# Runs <site id>-clean-up SSM command on all EC2 instances in the specified roles, 
# waits for all the command invocations to complete, and
# retrieves from S3 and prints outputs of the command invocations.
# Optionally, re-initializes the instances to generate a random password on first boot

import argparse
from time import sleep
import boto3
import ssm_utils

# Timeouts in seconds
WAIT_TIMEOUT = 600
SEND_TIMEOUT = 600 
EXECUTION_TIMEOUT = 1800

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ssm_clean_up.py',
        description='Runs <site id>-clean-up SSM command on EC2 instances of a deployment in certain roles.')

    parser.add_argument('-s', dest='site_id', help='ArcGIS Enterprise site Id')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment Id')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')
    parser.add_argument('-p', dest='sysprep', default='false', help='Run sysprep script')
    parser.add_argument('-u', dest='uninstall_chef_client', default='true', help='Uninstall Chef/Cinc Client')
    parser.add_argument('-f', dest='directories', default="", help='Comma-separated list of local directories to clean up')
    parser.add_argument('-b', dest='s3_bucket', help='Output S3 bucket')

    args = parser.parse_args()

    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')
    s3_client = boto3.client('s3')

    ec2_filters = [{
        'Name': 'tag:ArcGISSiteId',
        'Values': [args.site_id]
    }, {
        'Name': 'tag:ArcGISDeploymentId',
        'Values': [args.deployment_id]
    }, {
        'Name': 'tag:ArcGISMachineRole',
        'Values': args.machine_roles.split(',')
    }, {
        'Name': 'instance-state-name',
        'Values': ['pending', 'running']
    }]

    ssm_filters = [{
        'Key': 'tag:ArcGISSiteId',
        'Values': [args.site_id]
    },{
        'Key': 'tag:ArcGISDeploymentId',
        'Values': [args.deployment_id]
    },{
        'Key': 'tag:ArcGISMachineRole',
        'Values': args.machine_roles.split(',')
    }]

    if not ssm_utils.wait_for_target_instances(ec2_client, ssm_client, ec2_filters, ssm_filters, WAIT_TIMEOUT):
        exit(1)

    command_id = ssm_client.send_command(
        Targets=ssm_filters,
        DocumentName=args.site_id + '-clean-up',
        TimeoutSeconds=SEND_TIMEOUT,
        Comment='Deletes temporary files created by Chef runs.',
        Parameters={
            'Sysprep': [args.sysprep],
            'UninstallChefClient': [args.uninstall_chef_client],
            'Directories': [args.directories]
        },    
        OutputS3BucketName=args.s3_bucket,
        OutputS3KeyPrefix=args.deployment_id
    )['Command']['CommandId']

    status = ssm_utils.wait_for_command_invocations(ssm_client, command_id, EXECUTION_TIMEOUT)

    ssm_utils.print_command_output(s3_client, args.deployment_id, command_id, args.s3_bucket)

    exit(0 if status == 'Success' else 1)
