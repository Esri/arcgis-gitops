# Helper functions used by scripts that run SSM commands.

from time import sleep
import boto3

SLEEP_TIME = 10

# Wait until the target EC2 instances status is online
def wait_for_target_instances(ec2_client, ssm_client, ec2_filters, ssm_filters, wait_timeout):
    for i in range(wait_timeout // SLEEP_TIME):
        ec2_reservations = ec2_client.describe_instances(
            Filters=ec2_filters
        )['Reservations']

        ssm_instances = ssm_client.describe_instance_information(
            Filters=ssm_filters
        )['InstanceInformationList']
        
        if len(ssm_instances) > 0:
            ec2_instance_count = 0
            
            for reservation in ec2_reservations:
                ec2_instance_count += len(reservation['Instances'])
            
            online_instance_count = 0
            
            for instance in ssm_instances:
                if instance['PingStatus'] == 'Online':
                    online_instance_count += 1

            print("{0} of {1} target instances are online.".format(online_instance_count, ec2_instance_count))

            if online_instance_count == ec2_instance_count:
                return True

        sleep(SLEEP_TIME)
    
    print("Target instances are not online.")
    return False

# Wait for the command invocations to complete
def wait_for_command_invocations(ssm_client, command_id, execution_timeout):
    for i in range(execution_timeout // SLEEP_TIME):
        invocations = ssm_client.list_command_invocations(
            CommandId=command_id,
        )['CommandInvocations']

        if len(invocations) == 0:
            sleep(SLEEP_TIME)
            continue

        pending_executions_count = 0

        for invocation in invocations:
            if invocation['Status'] in ['Pending', 'InProgress']:
                pending_executions_count += 1
            elif invocation['Status'] in ['Cancelled', 'TimedOut', 'Failed']:
                print("Command {0} invocation {1} on instance {2}."
                      .format(command_id, invocation['Status'], invocation['InstanceId']))
                return invocation['Status']
        
        if pending_executions_count == 0:
            return 'Success'

        sleep(SLEEP_TIME)
    
    print("Command invocations timed out.")
    return 'TimedOut'

# Retrieve from S3 and prints outputs of the command invocations.
def print_command_output(s3_client, deployment_id, command_id, s3_bucket):
    key_prefix = deployment_id + '/' + command_id 

    keys = s3_client.list_objects_v2(Bucket=s3_bucket, MaxKeys=1000, Prefix=key_prefix)

    if 'Contents' in keys:
        for key in keys['Contents']:
            object = s3_client.get_object(Bucket=s3_bucket, Key=key['Key'])
            print()
            print("*** {0} ***".format(key['Key']))
            # print(object['Body'].read().decode('iso-8859-1', 'ignore'))
            for line in object['Body'].iter_lines():
                try:
                    print(line.decode('UTF-8', 'ignore'))
                except:
                    print(line)
