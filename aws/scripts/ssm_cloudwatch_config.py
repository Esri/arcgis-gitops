# Runs AmazonCloudWatch-ManageAgent SSM command on all EC2 instances in a deployment,
# waits for all the command invocations to complete, and
# retrieves from S3 and prints outputs of the command invocations.

import argparse
import boto3
import ssm_utils

# Timeouts in seconds
WAIT_TIMEOUT = 600
SEND_TIMEOUT = 600 
EXECUTION_TIMEOUT = 600

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ssm_cloudwatch_config.py',
        description='Runs AmazonCloudWatch-ManageAgent SSM command on all EC2 instances in a deployment.')

    parser.add_argument('-s', dest='site_id', help='ArcGIS Enterprise site Id')
    parser.add_argument('-d', dest='deployment_id', help='ArcGIS Enterprise deployment Id')
    parser.add_argument('-p', dest='parameter', help='SSM parameter name with CloudWatch agent configuration JSON')
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
        'Name': 'instance-state-name',
        'Values': ['pending', 'running']
    }]

    ssm_filters = [{
        'Key': 'tag:ArcGISSiteId',
        'Values': [args.site_id]
    }, {
        'Key': 'tag:ArcGISDeploymentId',
        'Values': [args.deployment_id]
    }]

    if not ssm_utils.wait_for_target_instances(ec2_client, ssm_client, ec2_filters, ssm_filters, WAIT_TIMEOUT):
        exit(1)

    command_id = ssm_client.send_command(
        Targets=ssm_filters,
        DocumentName='AmazonCloudWatch-ManageAgent',
        TimeoutSeconds=SEND_TIMEOUT,
        Comment='Installs AWS package on EC2 instances.',
        Parameters = { 
            'action': ['configure'],
            'optionalConfigurationSource': ['ssm'],
            'optionalConfigurationLocation': [args.parameter]
        },    
        OutputS3BucketName=args.s3_bucket,
        OutputS3KeyPrefix=args.deployment_id
    )['Command']['CommandId']

    status = ssm_utils.wait_for_command_invocations(ssm_client, command_id, EXECUTION_TIMEOUT)

    ssm_utils.print_command_output(s3_client, args.deployment_id, command_id, args.s3_bucket)

    exit(0 if status == 'Success' else 1)
