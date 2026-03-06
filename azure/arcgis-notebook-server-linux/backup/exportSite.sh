#!/bin/bash

# Copyright 2026 Esri
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
# and arcgisworkspace directory in the site's backup blob container.
#
# On the machine where the script is executed:
# 
# * Azure CLI must be installed and available in the PATH
# * jq command-line JSON processor must be installed
#
# The script expects the following environment variables to be set:
# * admin_username: admin username for the ArcGIS Notebook Server site
# * admin_password: admin password for the ArcGIS Notebook Server site
# * storage_account_name: the name of the Azure storage account where the backup will be stored
# * blob_container: the name of the blob container in the storage account where the backup will be stored
# * vm_identity_client_id: the client ID of the VM's user assigned managed identity

set -e

# Deployment-specific variables
ADMIN_URL="https://localhost:11443/arcgis/admin"
STAGING_LOCATION="/opt/tmp"
WORKSPACE_DIRECTORY="/mnt/fileserver/gisdata/notebookserver/directories/arcgisworkspace"

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install jq and try again."
  exit 1
fi

mkdir -p $STAGING_LOCATION
chmod 777 $STAGING_LOCATION

# Generate a token for the admin user and export the site
TOKEN_JSON=$(curl -ksS --request POST --data "username=$admin_username&password=$admin_password&client=referer&referer=referer&f=json" $ADMIN_URL/generateToken)
if [ $? -ne 0 ]; then
  echo "Error: Failed to generate token."
  exit 1
fi

TOKEN=$(echo $TOKEN_JSON | jq -r '.token')

RESPONSE_JSON=$(curl -ksS --request POST --data "location=$STAGING_LOCATION&token=$TOKEN&f=json" $ADMIN_URL/exportSite)
STATUS=$(echo $RESPONSE_JSON | jq -r '.status')
LOCATION=$(echo $RESPONSE_JSON | jq -r '.location')

if [ "$STATUS" == "success" ]; then
  echo "Exported site successfully. Staging location: $LOCATION"
  echo "Uploading to blob container '$blob_container' in storage account '$storage_account_name'..."
  
  az login --identity --client-id $vm_identity_client_id --output none

  # Create blob container if it doesn't exist
  az storage container create --name $blob_container --account-name $storage_account_name --auth-mode login --output none
  
  # Upload the backup file in the staging location to the blob container, then delete the local files if the upload is successful
  BACKUP_FILE=$(basename $LOCATION)
  az storage blob upload --file $LOCATION --account-name $storage_account_name --container-name $blob_container --name arcgissite/$BACKUP_FILE --overwrite true --auth-mode login --output none --no-progress
  if [ $? -eq 0 ]; then
    echo "Successfully uploaded to the blob container."
    rm -rf $LOCATION
  else
    echo "Failed to upload to the blob container."
    rm -rf $LOCATION
    exit 1
  fi

  # There are some directories that are not backed up by the export operation, 
  # notably the arcgisworkspace directory, which contains sample data and each notebook users' workspace data. 
  # Copy the workspace directory to the blob container along with the export file.
  az storage blob upload-batch --source $WORKSPACE_DIRECTORY --account-name $storage_account_name --destination $blob_container --destination-path arcgisworkspace/$BACKUP_FILE --overwrite true --auth-mode login --output none --no-progress
  if [ $? -eq 0 ]; then
    echo "Successfully uploaded workspace directory to the blob container."
  else
    echo "Failed to upload workspace directory to the blob container."
    exit 1
  fi
else
  echo "Failed to export site. Response: $RESPONSE_JSON" 
  exit 1
fi

echo "Export completed successfully."
