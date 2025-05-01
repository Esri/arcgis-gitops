#!/bin/bash

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

# This script builds container image for Enterprise Admin CLI and pushes it to
# private ECR repository in the AWS region.
#
# On the machine where the script is executed:
#
# * AWS CLI and Docker must be installed
# * AWS credentials must be configured for AWS CLI
# * AWS region must be specified by AWS_DEFAULT_REGION environment variable

JSON_ATTRIBUTES_PARAMETER='<json_attributes_parameter>'

ADMIN_URL="https://localhost:11443/arcgis/admin"
STAGING_LOCATION="/tmp"
WORKSPACE_DIRECTORY="/mnt/efs/gisdata/notebookserver/directories/arcgisworkspace"

# Get the script input parameters in JSON format from SSM Parameter Store
attributes=$(aws ssm get-parameter --name $JSON_ATTRIBUTES_PARAMETER --query 'Parameter.Value' --with-decryption --output text)

if [ $? -ne 0 ]; then
  echo "Error: Failed to retrieve '$JSON_ATTRIBUTES_PARAMETER' SSM parameter."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install jq and try again."
  exit 1
fi

# Get the parameters from the JSON string
ADMIN_PASSWORD=$(echo $attributes | jq -r '.admin_password')
ADMIN_USERNAME=$(echo $attributes | jq -r '.admin_username')
BACKUP_SITE_ID=$(echo $attributes | jq -r '.backup_site_id')
DEPLOYMENT_ID=$(echo $attributes | jq -r '.deployment_id')
RUN_AS_USER=$(echo $attributes | jq -r '.run_as_user')
S3_PREFIX=$(echo $attributes | jq -r '.s3_prefix')

# Get the backup S3 bucket and region from SSM Parameter Store
BACKUP_S3_BUCKET=$(aws ssm get-parameter --name "/arcgis/$BACKUP_SITE_ID/s3/backup" --query "Parameter.Value" --output text)
S3_REGION=$(aws ssm get-parameter --name "/arcgis/$BACKUP_SITE_ID/s3/region" --query "Parameter.Value" --output text)

# Get the last modified backup file key from S3
LAST_BACKUP_KEY=$(aws s3api list-objects-v2 --bucket $BACKUP_S3_BUCKET --prefix $S3_PREFIX --query "sort_by(Contents,&LastModified)[-1].Key" --output text)
aws s3 cp s3://$BACKUP_S3_BUCKET/$LAST_BACKUP_KEY $STAGING_LOCATION/ --region $S3_REGION
if [ $? -ne 0 ]; then
  echo "Failed to download the last backup from S3."
  exit 1
fi

BACKUP_FILE=$(basename $LAST_BACKUP_KEY)
if [ -z "$BACKUP_FILE" ]; then
  echo "No backup file found."
  exit 1
fi

STAGING_FILE_PATH="$STAGING_LOCATION/$BACKUP_FILE"

# Check if the file exists
if [ ! -f "$STAGING_LOCATION/$BACKUP_FILE" ]; then
  echo "Backup file not found in staging location."
  exit 1
fi

echo "Importing site from backup file: s3://$BACKUP_S3_BUCKET/$LAST_BACKUP_KEY"
TOKEN_JSON=$(curl -k --request POST --data "username=$ADMIN_USERNAME&password=$ADMIN_PASSWORD&client=referer&referer=referer&f=json" $ADMIN_URL/generateToken)

if [ $? -ne 0 ]; then
  echo "Error: Failed to generate token."
  exit 1
fi

TOKEN=$(echo $TOKEN_JSON | jq -r '.token')

RESPONSE_JSON=$(curl -k --request POST --data "location=$STAGING_FILE_PATH&token=$TOKEN&f=json" $ADMIN_URL/importSite)
STATUS=$(echo $RESPONSE_JSON | jq -r '.status')

if [ "$STATUS" == "success" ]; then
  echo "Imported site successfully from s3://$BACKUP_S3_BUCKET/$LAST_BACKUP_KEY."
  rm -rf $STAGING_FILE_PATH
else
  echo "Failed to import site. Response: $RESPONSE_JSON"
  rm -rf $STAGING_FILE_PATH
  exit 1
fi

# There are some directories that are not restored by the import operation,
# notably the arcgisworkspace directory, which contains sample data and each notebook users' workspace data.
# Copy the workspace directory from S3.
aws s3 cp s3://$BACKUP_S3_BUCKET/arcgisworkspace/$BACKUP_FILE $WORKSPACE_DIRECTORY --region $S3_REGION --recursive
if [ $? -eq 0 ]; then
  echo "Successfully restored workspace directory from S3."
else
  echo "Failed to restore workspace directory from S3."
  exit 1
fi

# Set the ownership of the restored directory to the arcgis user and group
chown -R $RUN_AS_USER:$RUN_AS_USER $WORKSPACE_DIRECTORY

echo "Site restoration completed successfully."