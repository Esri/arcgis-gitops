# The script runs Chef Client in solo mode on EC2 instances of a deployment.
# 
# The script retrieves the Chef JSON attributes from the JSON_ATTRIBUTES environment variable
# and puts them into SecureString SSM parameter specified by json_attributes_parameter command line argument.
# To execute Chef Client the script runs <site id>-run-chef SSM command on EC2 instances of the deployment
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
        prog='ssm_run_chef.py',
        description='Runs <site id>-run-chef SSM command on EC2 instances of a deployment in certain roles.')

    parser.add_argument('-s', dest='site_id', help='Site Id')
    parser.add_argument('-d', dest='deployment_id', help='Deployment Id')
    parser.add_argument('-m', dest='machine_roles', help='Machine roles')
    parser.add_argument('-j', dest='json_attributes_parameter', help='SSM parameter name of role attributes')
    parser.add_argument('-b', dest='s3_bucket', help='Output S3 bucket')
    parser.add_argument('-e', dest='execution_timeout', help='Execution timeout (seconds)')

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
    }, {
        'Key': 'tag:ArcGISDeploymentId',
        'Values': [args.deployment_id]
    }, {
        'Key': 'tag:ArcGISMachineRole',
        'Values': args.machine_roles.split(',')
    }]

    if not ssm_utils.wait_for_target_instances(ec2_client, ssm_client, ec2_filters, ssm_filters, WAIT_TIMEOUT):
        exit(1)

    # Put JSON attributes to SSM parameter if JSON_ATTRIBUTES env variable is defined
    if 'JSON_ATTRIBUTES' in os.environ:
        jsonAttributes = base64.b64decode(os.environ['JSON_ATTRIBUTES']).decode('utf-8')
    
        print("Creating SecureString SSM parameter {0}...".format(args.json_attributes_parameter))

        ssm_client.put_parameter(
            Name=args.json_attributes_parameter,
            Description='Chef run attributes in JSON format',
            Value=jsonAttributes,
            Type='SecureString',
            Tags=[
                {
                    'Key': 'ArcGISSiteId',
                    'Value': args.site_id
                },
            ],
            Tier='Intelligent-Tiering'
        )

    command_id = ssm_client.send_command(
        Targets=ssm_filters,
        DocumentName=args.site_id + '-run-chef',
        TimeoutSeconds=SEND_TIMEOUT,
        Comment='Runs Chef client with a specific role JSON file.',
        Parameters={
            'JsonAttributes': [args.json_attributes_parameter],
            'ExecutionTimeout': [args.execution_timeout]
        },    
        OutputS3BucketName=args.s3_bucket,
        OutputS3KeyPrefix=args.deployment_id
    )['Command']['CommandId']

    status = ssm_utils.wait_for_command_invocations(ssm_client, command_id, int(args.execution_timeout))

    print("Deleting SecureString SSM parameter {0}...".format(args.json_attributes_parameter))
    
    ssm_client.delete_parameter(
        Name=args.json_attributes_parameter
    )

    ssm_utils.print_command_output(s3_client, args.deployment_id, command_id, args.s3_bucket)

    exit(0 if status == 'Success' else 1)
