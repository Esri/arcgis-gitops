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

# This script restores the ArcGIS Notebook Server deployment's config store
# and arcgisworkspace directory from the site's backup Azure blob storage.
#
# On the machine where the script is executed:
#
# * Azure CLI must be installed and available in the PATH
# * jq command-line JSON processor must be installed
#
# The script expects the following environment variables to be set:
# * admin_username: admin username for the ArcGIS Notebook Server site
# * admin_password: admin password for the ArcGIS Notebook Server site
# * storage_account_name: the name of the Azure storage account where the backup is stored
# * blob_container: the name of the blob container in the storage account where the backup is stored
# * vm_identity_client_id: the client ID of the VM's user assigned managed identity
# * run_as_user: the user that the ArcGIS Notebook Server processes run as, used to set ownership of the restored workspace directory

set -e

ADMIN_URL="https://localhost:11443/arcgis/admin"
STAGING_LOCATION="/opt/tmp"
WORKSPACE_DIRECTORY="/mnt/fileserver/gisdata/notebookserver/directories/arcgisworkspace"

if ! command -v jq &> /dev/null; then
  echo "Error: jq is not installed. Please install jq and try again."
  exit 1
fi

mkdir -p $STAGING_LOCATION
chmod 777 $STAGING_LOCATION

az login --identity --client-id $vm_identity_client_id --output none

echo "Looking for the latest backup file in blob container '$blob_container' in storage account '$storage_account_name'..."

# Get the last modified backup file key from the blob container 
LAST_BACKUP_KEY=$(az storage blob list --account-name $storage_account_name --container-name $blob_container --prefix arcgissite --query "sort_by([], &properties.lastModified)[-1].name" --output tsv --auth-mode login)

BACKUP_FILE=$(basename $LAST_BACKUP_KEY)
if [ -z "$BACKUP_FILE" ]; then
  echo "No backup file found."
  exit 1
fi

echo "Found backup file: $LAST_BACKUP_KEY. Downloading to staging location..."

STAGING_FILE_PATH="$STAGING_LOCATION/$BACKUP_FILE"

az storage blob download --account-name $storage_account_name --container-name $blob_container --name $LAST_BACKUP_KEY --file $STAGING_FILE_PATH --auth-mode login --output none --no-progress
if [ $? -ne 0 ]; then
  echo "Failed to download the last backup from blob container."
  exit 1
fi

# Check if the file exists
if [ ! -f "$STAGING_FILE_PATH" ]; then
  echo "Backup file not found in staging location."
  exit 1
fi

echo "Importing site from backup file $STAGING_FILE_PATH..."

TOKEN_JSON=$(curl -ksS --request POST --data "username=$admin_username&password=$admin_password&client=referer&referer=referer&f=json" $ADMIN_URL/generateToken)

if [ $? -ne 0 ]; then
  echo "Error: Failed to generate token."
  exit 1
fi

TOKEN=$(echo $TOKEN_JSON | jq -r '.token')

RESPONSE_JSON=$(curl -ksS --request POST --data "location=$STAGING_FILE_PATH&token=$TOKEN&f=json" $ADMIN_URL/importSite)
STATUS=$(echo $RESPONSE_JSON | jq -r '.status')

if [ "$STATUS" == "success" ]; then
  echo "Site imported successfully."
  rm -rf $STAGING_FILE_PATH
else
  echo "Failed to import site. Response: $RESPONSE_JSON"
  rm -rf $STAGING_FILE_PATH
  exit 1
fi

# There are some directories that are not restored by the import operation,
# notably the arcgisworkspace directory, which contains sample data and each notebook users' workspace data.
# Copy the workspace directory from the blob container.

echo "Restoring the workspace directory from backup blob container..."

WORKSPACE_RESTORE_STAGING="$STAGING_LOCATION/workspace-restore-$BACKUP_FILE"
rm -rf "$WORKSPACE_RESTORE_STAGING"
mkdir -p "$WORKSPACE_RESTORE_STAGING"
chmod 777 "$WORKSPACE_RESTORE_STAGING"

az storage blob download-batch --account-name $storage_account_name --source $blob_container --pattern "arcgisworkspace/$BACKUP_FILE/*" --destination "$WORKSPACE_RESTORE_STAGING" --overwrite true --auth-mode login --output none --no-progress
if [ $? -eq 0 ]; then
  RESTORED_WORKSPACE_CONTENT="$WORKSPACE_RESTORE_STAGING/arcgisworkspace/$BACKUP_FILE"
  if [ -d "$RESTORED_WORKSPACE_CONTENT" ]; then
    mkdir -p "$WORKSPACE_DIRECTORY"
    cp -a "$RESTORED_WORKSPACE_CONTENT/." "$WORKSPACE_DIRECTORY/"
    rm -rf "$WORKSPACE_RESTORE_STAGING"
    ls -la "$WORKSPACE_DIRECTORY"
    echo "Successfully restored workspace directory."
  else
    echo "Failed to restore workspace directory: expected path '$RESTORED_WORKSPACE_CONTENT' not found in downloaded backup."
    rm -rf "$WORKSPACE_RESTORE_STAGING"
    exit 1
  fi
else
  echo "Failed to restore workspace directory."
  rm -rf "$WORKSPACE_RESTORE_STAGING"
  exit 1
fi

# Set the ownership of the restored directory to the arcgis user and group
chown -R $run_as_user:$run_as_user $WORKSPACE_DIRECTORY
chmod -R 777 $WORKSPACE_DIRECTORY

echo "Site restoration completed successfully."