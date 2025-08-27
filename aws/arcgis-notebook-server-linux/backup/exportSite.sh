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

# This script backs up the ArcGIS Notebook Server deployment's config store
# and arcgisworkspace directory in the site's backup S3 bucket.
#
# On the machine where the script is executed:
#
# * AWS CLI and Docker must be installed
# * AWS credentials must be configured for AWS CLI
# * AWS region must be specified by AWS_DEFAULT_REGION environment variable

JSON_ATTRIBUTES_PARAMETER='<json_attributes_parameter>'

# Deployment-specific variables
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
SITE_ID=$(echo $attributes | jq -r '.site_id')
DEPLOYMENT_ID=$(echo $attributes | jq -r '.deployment_id')
ADMIN_USERNAME=$(echo $attributes | jq -r '.admin_username')
ADMIN_PASSWORD=$(echo $attributes | jq -r '.admin_password')
S3_PREFIX=$(echo $attributes | jq -r '.s3_prefix')

# Get the S3 bucket and region from SSM Parameter Store
BACKUP_S3_BUCKET=$(aws ssm get-parameter --name "/arcgis/$SITE_ID/s3/backup" --query "Parameter.Value" --output text)
S3_REGION=$(aws ssm get-parameter --name "/arcgis/$SITE_ID/s3/region" --query "Parameter.Value" --output text)

# Generate a token for the admin user and export the site
TOKEN_JSON=$(curl -k --request POST --data "username=$ADMIN_USERNAME&password=$ADMIN_PASSWORD&client=referer&referer=referer&f=json" $ADMIN_URL/generateToken)
if [ $? -ne 0 ]; then
  echo "Error: Failed to generate token."
  exit 1
fi

TOKEN=$(echo $TOKEN_JSON | jq -r '.token')

RESPONSE_JSON=$(curl -k --request POST --data "location=$STAGING_LOCATION&token=$TOKEN&f=json" $ADMIN_URL/exportSite)
STATUS=$(echo $RESPONSE_JSON | jq -r '.status')
LOCATION=$(echo $RESPONSE_JSON | jq -r '.location')

if [ "$STATUS" == "success" ]; then
  echo "Exported site successfully. Staging location: $LOCATION"
  echo "Uploading to S3 bucket: $BACKUP_S3_BUCKET in $S3_REGION region"
  aws s3 cp $LOCATION s3://$BACKUP_S3_BUCKET/$S3_PREFIX/ --region $S3_REGION
  if [ $? -eq 0 ]; then
    echo "Successfully uploaded to S3."
    rm -rf $LOCATION
  else
    echo "Failed to upload to S3."
    rm -rf $LOCATION
    exit 1
  fi

  # There are some directories that are not backed up by the export operation, 
  # notably the arcgisworkspace directory, which contains sample data and each notebook users' workspace data. 
  # Copy the workspace directory to S3 along with the export file.
  BACKUP_FILE=$(basename $LOCATION)
  aws s3 cp $WORKSPACE_DIRECTORY s3://$BACKUP_S3_BUCKET/arcgisworkspace/$BACKUP_FILE --region $S3_REGION --recursive
  if [ $? -eq 0 ]; then
    echo "Successfully uploaded workspace directory to S3."
  else
    echo "Failed to upload workspace directory to S3."
    exit 1
  fi
else
  echo "Failed to export site. Response: $RESPONSE_JSON" 
  exit 1
fi

echo "Export completed successfully."
