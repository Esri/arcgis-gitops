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

# The script is designed to recover an ArcGIS Enterprise deployment on AWS using AWS Backup. 
# It automates the restoration of key AWS resources associated with an ArcGIS deployment, including:
#
# * S3 buckets
# * EFS file systems
# * EC2 instances
# * DynamoDB tables 
#
# Key features:
#
# * Identifies and restores the latest valid recovery points for each resource type, 
#   filtered by ArcGIS site and deployment IDs, and (optionally) by the backup time.
# * Uses ArcGISSiteId, ArcGISDeploymentId, ArcGISRole, and ArcGISMachineRole
#   tags to identify the deployment's resources to recover and the recovery points.
# * Waits for the restore jobs to complete and logs progress.
# * Updates configuration references such as SSM parameters, AWS Backup plan resource selections,
#   and DynamoDB tables to point to the newly restored resources.
# * Supports a test mode to validate recovery points without making changes.

import argparse
from http import client
import boto3
from datetime import datetime, timezone
from dateutil import parser
import time
import logging

# The script uses tags to identify the deployment's resources to recover and the recovery points.
DEPLOYMENT_ID_TAG = 'ArcGISDeploymentId'
SITE_ID_TAG       = 'ArcGISSiteId'
ROLE_TAG          = 'ArcGISRole'
MACHINE_ROLE_TAG  = 'ArcGISMachineRole'

# Roles
CONFIG_STORE_ROLE = 'config-store'

CONFIG_STORES_TABLE_NAME = 'ArcGISConfigStores'

MAX_WAIT_TIME = 3600 # Maximum wait time for restore jobs in seconds
SLEEP_INTERVAL = 30  # Sleep interval between status checks in seconds

logger = logging.getLogger("recover.deployment")

# Global timestamp
timestamp = datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')

ec2_client     = boto3.client('ec2')
efs_client     = boto3.client('efs')
s3_client      = boto3.client('s3')
dynamodb_client = boto3.client('dynamodb')
ssm_client     = boto3.client('ssm')
backup_client  = boto3.client('backup')


# The function recovers ArcGIS Server config store DynamoDB table and S3 bucket
# of the specified site and deployment from AWS Backup recovery points.
# Returns ARNs of the restored application resources.
def restore_server_config_store(backup_vault, site_id, deployment_id, backup_date, backup_plan_id, backup_role_arn, test_mode):
    # Find the recovery points for the DynamoDB table and S3 bucket that were created before the specified backup date.
    db_recovery_points = get_recovery_points(backup_vault, 'DynamoDB', site_id, deployment_id, backup_date)
    s3_recovery_points = get_recovery_points(backup_vault, 'S3', site_id, deployment_id, backup_date)

    if CONFIG_STORE_ROLE not in db_recovery_points or CONFIG_STORE_ROLE not in s3_recovery_points:
        logger.info(f"No cloud config store recovery points found for deployment {site_id}/{deployment_id}.")
        return

    deployment_namespace = f"{site_id}-{deployment_id}"

    if CONFIG_STORE_ROLE not in db_recovery_points:
        raise Exception(f"No recovery points found for the config store DynamoDB table.")

    if CONFIG_STORE_ROLE not in s3_recovery_points:
        raise Exception(f"No recovery points found for the config store S3 bucket.")

    db_table_recovery_point = db_recovery_points[CONFIG_STORE_ROLE]
    s3_bucket_recovery_point = s3_recovery_points[CONFIG_STORE_ROLE]

    new_db_table_name = f"ArcGISConfigStore.{site_id}-{deployment_id}-{timestamp}"
    new_s3_bucket_name = f"{site_id}-{deployment_id}-config-store-{timestamp}"

    if test_mode:
        logger.info(f"Restoring recovery point '{db_table_recovery_point['RecoveryPointArn']}' ({db_table_recovery_point['CreationDate']}) to new DynamoDB table {new_db_table_name}...")
        logger.info(f"Restoring recovery point '{s3_bucket_recovery_point['RecoveryPointArn']}' ({s3_bucket_recovery_point['CreationDate']}) to new S3 bucket {new_s3_bucket_name}...")
        return

    logger.info("Starting config store restore jobs...")

    job_ids = []

    job_ids.append(backup_client.start_restore_job(
        RecoveryPointArn=s3_bucket_recovery_point['RecoveryPointArn'],
        Metadata={
            'DestinationBucketName': new_s3_bucket_name,
            'NewBucket': 'true'
        },
        ResourceType='S3',
        IamRoleArn=backup_role_arn
    )['RestoreJobId'])

    job_ids.append(backup_client.start_restore_job(
        RecoveryPointArn=db_table_recovery_point['RecoveryPointArn'],
        Metadata={
            'targetTableName': new_db_table_name
        },
        ResourceType='DynamoDB',
        IamRoleArn=backup_role_arn
    )['RestoreJobId'])

    # Wait for the restore jobs to complete
    jobs = wait_for_restore_jobs(job_ids)

    new_resources = []
    for job in jobs:
        if job['Status'] != 'COMPLETED':
            raise Exception(f"Restoring from recovery point {job['RecoveryPointArn']} failed. {job['StatusMessage']}")
        
        if job['ResourceType'] == 'DynamoDB':
            dynamodb_client.tag_resource(
                ResourceArn=job['CreatedResourceArn'],
                Tags=[{
                    'Key': SITE_ID_TAG,
                    'Value': site_id
                },
                {
                    'Key': DEPLOYMENT_ID_TAG,
                    'Value': deployment_id
                },
                {
                    'Key': ROLE_TAG,
                    'Value': CONFIG_STORE_ROLE
                }]
            )

        if job['ResourceType'] == 'S3':
            s3_client.put_bucket_tagging(
                Bucket=new_s3_bucket_name,
                Tagging={
                    'TagSet': [{
                        'Key': SITE_ID_TAG,
                        'Value': site_id
                    },
                    {
                        'Key': DEPLOYMENT_ID_TAG,
                        'Value': deployment_id
                    },
                    {
                        'Key': ROLE_TAG,
                        'Value': CONFIG_STORE_ROLE
                    }]
                }
            )

        logger.info(f"Recovery point {job['RecoveryPointArn']} restored to {job['CreatedResourceArn']}.")
        new_resources.append(job['CreatedResourceArn'])

    logger.info(f"Updating namespace '{deployment_namespace}' in ArcGISConfigStores table with the new DynamoDB table and S3 bucket names...")

    try:
        dynamodb_client.describe_table(TableName=CONFIG_STORES_TABLE_NAME)
    except dynamodb_client.exceptions.ResourceNotFoundException:
        logger.info(f"Table '{CONFIG_STORES_TABLE_NAME}' does not exist. Creating...")

        table = dynamodb_client.create_table(
            TableName=CONFIG_STORES_TABLE_NAME,
            KeySchema=[
                {
                    'AttributeName': 'Namespace',
                    'KeyType': 'HASH'
                }
            ],
            AttributeDefinitions=[
                {
                    'AttributeName': 'Namespace',
                    'AttributeType': 'S'
                }
            ],
            ProvisionedThroughput={
                'ReadCapacityUnits': 5,
                'WriteCapacityUnits': 5
            }
        )

        table.wait_until_exists()

    dynamodb_client.update_item(
        TableName=CONFIG_STORES_TABLE_NAME,
        Key={
            'Namespace': {
                'S': deployment_namespace
            }
        },
        AttributeUpdates={
            'DBTableName': {
                'Value': {
                    'S': new_db_table_name
                },
                'Action': 'PUT'
            },
            'S3BucketName': {
                'Value': {
                    'S': new_s3_bucket_name
                },
                'Action': 'PUT'
            }
        }
    )

    logger.info(f"Updating the backup plan resource assignments with new resources.")

    backup_selections = backup_client.list_backup_selections(
        BackupPlanId=backup_plan_id
    )['BackupSelectionsList']

    for selection in backup_selections:
        backup_selection = backup_client.get_backup_selection(
            BackupPlanId=selection['BackupPlanId'],
            SelectionId=selection['SelectionId']
        )['BackupSelection']

        if backup_selection['SelectionName'].endswith("-application"):
            # Delete the old backup selection and create a new one
            backup_client.delete_backup_selection(
                BackupPlanId=backup_plan_id,
                SelectionId=selection['SelectionId']
            )

            backup_client.create_backup_selection(
                BackupPlanId=backup_plan_id,
                BackupSelection={
                    'SelectionName': backup_selection['SelectionName'],
                    'IamRoleArn': backup_selection['IamRoleArn'],
                    'Resources': new_resources,
                    'ListOfTags': backup_selection['ListOfTags'],
                    'Conditions': backup_selection.get('Conditions', {}),
                    'NotResources': backup_selection.get('NotResources', [])
                }
            )

            break
    
    logger.info("Server config store resources restored successfully.")


# Restore the deployment infrastructure from AWS backup 
def restore_deployment_infrastructure(backup_vault, site_id, deployment_id, backup_date, backup_role_arn, test_mode):
    # Retrieve recovery points for S3, EFS, and EC2 resources
    s3_recovery_points  = get_recovery_points(backup_vault, 'S3', site_id, deployment_id, backup_date)
    efs_recovery_points = get_recovery_points(backup_vault, 'EFS', site_id, deployment_id, backup_date)
    ec2_recovery_points = get_recovery_points(backup_vault, 'EC2', site_id, deployment_id, backup_date)

    s3_buckets = deployment_s3_buckets(site_id, deployment_id)
    for role, bucket in s3_buckets.items():
        if role not in s3_recovery_points:
            raise Exception(f"No recovery point found for {role} S3 bucket '{bucket}'.")

        recovery_point = s3_recovery_points.get(role)
        if test_mode:
            logger.info(f"Restoring {role} S3 bucket '{bucket}' from recovery point '{recovery_point['RecoveryPointArn']}' ({recovery_point['CreationDate']})...")

    efs_file_systems = deployment_efs_file_systems(site_id, deployment_id)
    for role, file_system in efs_file_systems.items():
        if role not in efs_recovery_points:
            raise Exception(f"No recovery point found for {role} EFS file system '{file_system}'.")

        recovery_point = efs_recovery_points.get(role)
        if test_mode:
            logger.info(f"Restoring {role} EFS file system '{file_system}' from recovery point '{recovery_point['RecoveryPointArn']}' ({recovery_point['CreationDate']})...")

    ec2_instances = deployment_ec2_instances(site_id, deployment_id)
    for role, instance_id in ec2_instances.items():
        if role not in ec2_recovery_points:
            raise Exception(f"No recovery point found for {role} EC2 instance '{instance_id}'.")

        recovery_point = ec2_recovery_points.get(role)
        if test_mode:
            logger.info(f"Restoring {role} EC2 instance '{instance_id}' from image '{recovery_point['RecoveryPointArn']}' ({recovery_point['CreationDate']})...")

    if test_mode:
        return

    job_ids = []
    
    for role, bucket in s3_buckets.items():
        job_ids.append(backup_client.start_restore_job(
            RecoveryPointArn=s3_recovery_points.get(role)['RecoveryPointArn'],
            Metadata={
                'DestinationBucketName': bucket,
            },
            ResourceType='S3',
            IamRoleArn=backup_role_arn
        )['RestoreJobId'])

    for role, file_system_id in efs_file_systems.items():
        if role and role in efs_recovery_points:
            job_ids.append(backup_client.start_restore_job(
                RecoveryPointArn=efs_recovery_points.get(role)['RecoveryPointArn'],
                Metadata={
                    'file-system-id': file_system_id,
                    'newFileSystem': 'false'
                },
                ResourceType='EFS',
                IamRoleArn=backup_role_arn
            )['RestoreJobId'])

    update_deployment_images(site_id, deployment_id, ec2_recovery_points)

    wait_for_restore_jobs(job_ids)


# Retrieves recovery points for the specified resource type based on the specified 
# site ID, deployment ID, and backup time.
# Returns a dictionary with recovery points for each resource role.
def get_recovery_points(backup_vault, resource_type, site_id, deployment_id, backup_time):
    protected_resources = []
    paginator = backup_client.get_paginator('list_protected_resources_by_backup_vault')
    for page in paginator.paginate(BackupVaultName=backup_vault):
        protected_resources.extend(page['Results'])

    # Get all the recovery points in the vault for the specified resource type 
    # belonging to the specified site and deployment ids and created before the specified date.
    resource_recovery_points = []
    for protected_resource in protected_resources:
        if protected_resource['ResourceType'] != resource_type:
            continue

        recovery_points_by_resource = []
        paginator = backup_client.get_paginator('list_recovery_points_by_resource')
        for page in paginator.paginate(ResourceArn=protected_resource['ResourceArn']):
            recovery_points_by_resource.extend(page['RecoveryPoints'])

        for recovery_point in recovery_points_by_resource:
            if recovery_point['Status'] != 'COMPLETED' or recovery_point['CreationDate'] > backup_time:
                    continue
                    
            tags = backup_client.list_tags(
                ResourceArn=recovery_point['RecoveryPointArn']
            )['Tags']

            if (SITE_ID_TAG in tags and tags[SITE_ID_TAG] == site_id and \
               DEPLOYMENT_ID_TAG in tags and tags[DEPLOYMENT_ID_TAG] == deployment_id):
                resource_recovery_points.append(recovery_point)

    # Sort recovery points by creation date in descending order
    resource_recovery_points.sort(key=lambda x: x['CreationDate'], reverse=True)

    recovery_points = {}

    # Group recovery points by ArcGISMachineRole or ArcGISRole tag
    for recovery_point in resource_recovery_points:
        tags = backup_client.list_tags(
            ResourceArn=recovery_point['RecoveryPointArn']
        )['Tags']

        role = tags.get(MACHINE_ROLE_TAG, tags.get(ROLE_TAG, recovery_point['ResourceName']))
        if role not in recovery_points:
            recovery_points[role] = recovery_point

    return recovery_points


# Retrieves EC2 instances for the specified site and deployment IDs.
def deployment_ec2_instances(site_id, deployment_id):
    instances = ec2_client.describe_instances(
        Filters=[
            {
                'Name': f'tag:{SITE_ID_TAG}',
                'Values': [
                    site_id
                ]
            },
            {
                'Name': f'tag:{DEPLOYMENT_ID_TAG}',
                'Values': [
                    deployment_id
                ]
            }, 
            {
                'Name': 'instance-state-name',
                'Values': [
                    'running',
                    'stopped'
                ]
            }
        ]
    )

    instance_ids = {}

    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            role = next((tag['Value'] for tag in instance['Tags'] if tag['Key'] == MACHINE_ROLE_TAG), None)
            if role is not None:
                instance_ids[role] = instance['InstanceId']

    return instance_ids

# Updates the deployment images in SSM Parameter Store.
def update_deployment_images(site_id, deployment_id, ec2_recovery_points):
    for role, recovery_point in ec2_recovery_points.items():
        ami_id = recovery_point['RecoveryPointArn'].split('/')[-1]  # Extract AMI ID from ARN

        ssm_client.put_parameter(
            Name=f"/arcgis/{site_id}/images/{deployment_id}/{role}",
            Value=ami_id,
            Type="String",
            Overwrite=True,
            Tier='Intelligent-Tiering'
        )

        logger.info(f"Updated AMI for {role} role to backup AMI {ami_id}.")

# Retrieves S3 buckets for the specified site and deployment IDs.
def deployment_s3_buckets(site_id, deployment_id):
    s3_buckets = {}
    
    # For some reason list_buckets paginator does not work.
    while True:
        response = s3_client.list_buckets(Prefix=site_id)

        for bucket in response.get('Buckets', []):
            try:
                bucket_tagging = s3_client.get_bucket_tagging(Bucket=bucket['Name'])
            except s3_client.exceptions.ClientError as e:
                continue

            tag_dict = {tag['Key']: tag['Value'] for tag in bucket_tagging['TagSet']}

            if tag_dict.get(SITE_ID_TAG) == site_id and \
               tag_dict.get(DEPLOYMENT_ID_TAG) == deployment_id and \
               tag_dict.get(ROLE_TAG) != CONFIG_STORE_ROLE and \
               ROLE_TAG in tag_dict:
                s3_buckets[tag_dict[ROLE_TAG]] = bucket['Name']

        if 'NextContinuationToken' in response:
            response = s3_client.list_buckets(
                Prefix=site_id,
                ContinuationToken=response['NextContinuationToken']
            )
        else:
            break

    return s3_buckets


# Waits for the completion of the specified restore jobs.
# Returns a dictionary with job states for each role.
def wait_for_restore_jobs(job_ids):
    jobs = []

    for job_id in job_ids:
        for _ in range(MAX_WAIT_TIME // SLEEP_INTERVAL):
            job = backup_client.describe_restore_job(
                RestoreJobId=job_id
            )

            if job['Status'] in ['COMPLETED', 'FAILED', 'ABORTED']:
                jobs.append(job)
                break
            
            logger.info(f"Waiting for restore job {job_id} to complete. Current status: {job['Status']}")
            time.sleep(SLEEP_INTERVAL)

    return jobs

# Wait for all restore jobs and replace root volume tasks to complete.
def wait_for_running_restore_jobs():
    for _ in range(MAX_WAIT_TIME // SLEEP_INTERVAL):
        pending_jobs = backup_client.list_restore_jobs(
            ByStatus='PENDING'
        )['RestoreJobs']

        running_jobs = backup_client.list_restore_jobs(
            ByStatus='RUNNING'
        )['RestoreJobs']

        if len(pending_jobs) == 0 and len(running_jobs) == 0:
            break

        time.sleep(SLEEP_INTERVAL)


# Retrieves the EFS file systems for the specified site and deployment IDs.
def deployment_efs_file_systems(site_id, deployment_id):
    file_systems = {}

    for file_system in efs_client.describe_file_systems()['FileSystems']:
        # Skip file systems that are not tagged with ArcGISSiteId and ArcGISDeploymentId
        tags = {tag['Key']: tag['Value'] for tag in file_system.get('Tags', [])}
        if SITE_ID_TAG not in tags or DEPLOYMENT_ID_TAG not in tags or ROLE_TAG not in tags or \
            tags.get(SITE_ID_TAG) != site_id or tags.get(DEPLOYMENT_ID_TAG) != deployment_id:
            continue

        role = tags.get(ROLE_TAG)

        if role not in file_systems:
            file_systems[role] = file_system['FileSystemId']

    return file_systems

# Restores the EFS file systems from the specified recovery points.
def restore_efs_file_systems(file_systems, recovery_points, backup_role_arn):
    job_ids = {}

    for role, file_system_id in file_systems.items():
        if role and role in recovery_points:
            job_ids[role] = backup_client.start_restore_job(
                RecoveryPointArn=recovery_points.get(role),
                Metadata={
                    'file-system-id': file_system_id,
                    'newFileSystem': 'false'
                },
                ResourceType='EFS',
                IamRoleArn=backup_role_arn
            )['RestoreJobId']

    return job_ids


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s: %(message)s')
    
    arg_parser = argparse.ArgumentParser(
        prog='recover_deployment.py',
        description='Recovers deployment from AWS Backup.')

    arg_parser.add_argument('-s', '--site-id', dest='site_id', required=True, help='ArcGIS Enterprise site Id')
    arg_parser.add_argument('-d', '--deployment-id', dest='deployment_id', required=True, help='ArcGIS Enterprise deployment Id')
    arg_parser.add_argument('-c', '--backup-time', dest='backup_time', default=None, help='Use recovery points that were created before the specified timestamp in ISO 8601 format (e.g., 2024-01-01T00:00:00Z)')
    arg_parser.add_argument('-t', '--test-mode', dest='test_mode', action="store_true", help='Run in test mode without making changes.')

    args = arg_parser.parse_args()

    backup_time = datetime.now(timezone.utc)

    if args.backup_time:
        backup_time = parser.parse(args.backup_time)

    logger.info(f"Recovering deployment {args.site_id}/{args.deployment_id} from AWS Backup created before {backup_time}...")

    backup_client = boto3.client('backup')

    backup_vault = ssm_client.get_parameter(
        Name=f"/arcgis/{args.site_id}/backup/vault-name",
        WithDecryption=True
    )['Parameter']['Value']

    backup_plan_id = ssm_client.get_parameter(
        Name=f"/arcgis/{args.site_id}/{args.deployment_id}/backup/plan-id",
        WithDecryption=True
    )['Parameter']['Value']

    backup_role_arn = ssm_client.get_parameter(
        Name=f"/arcgis/{args.site_id}/iam/backup-role-arn",
        WithDecryption=True
    )['Parameter']['Value']

    # Restore server config store and infrastructure in test mode first
    # to ensure that all the required recovery points exist.
    restore_server_config_store(backup_vault, args.site_id, args.deployment_id, backup_time, backup_plan_id, backup_role_arn, True)
    restore_deployment_infrastructure(backup_vault, args.site_id, args.deployment_id, backup_time, backup_role_arn, True)

    if args.test_mode:
        logger.info("Running in test mode. No changes will be made.")
        exit(0)

    logger.info("Waiting for all existing restore jobs to complete before starting new ones...")

    wait_for_running_restore_jobs()

    logger.info("Starting recovery of the deployment...")

    restore_server_config_store(backup_vault, args.site_id, args.deployment_id, backup_time, backup_plan_id, backup_role_arn, False)
    restore_deployment_infrastructure(backup_vault, args.site_id, args.deployment_id, backup_time, backup_role_arn, False)

    logger.info("Deployment recovery completed.")
