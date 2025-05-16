# Backup Script for ArcGIS Notebook Server on Linux

The `exportSite.sh` script automates the process of backing up an ArcGIS Notebook Server deployment and securely storing the backup in the ArcGIS Enterprise site's backup S3 bucket (see [Back up and restore ArcGIS Notebook Server](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/back-up-and-restore-arcgis-notebook-server.htm)).

The script is designed to be executed by ssm_run_shell_script python module on the primary EC2 instance of the ArcGIS Notebook Server deployment. It uses AWS CLI commands to interact with Amazon S3 for backup storage and AWS Systems Manager (SSM) Parameter Store to retrieve configuration details.

> The ssm_run_shell_script python module replaces `<json_attributes_parameter>` placeholder with the actual SSM parameter name containing the JSON object with the script input parameters.

The script performs the following tasks:

* Fetches the configuration details from SSM Parameter Store.
* Sends a request to the server's [exportSite](https://developers.arcgis.com/rest/enterprise-administration/notebook/export-site-notebook-server/) endpoint to create a backup of the ArcGIS Notebook Server configuration store and save it to a specified staging location.
* Uploads the exported backup file from the staging location to the backup S3 bucket.
* Uploads the ArcGIS Notebook Server workspace directory to the backup S3 bucket.
* Deletes the backup file from the staging location.

## Requirements

On the machine where the script is executed:

* AWS CLI must be installed and configured with the necessary permissions to access the backup S3 bucket.
* jq command-line JSON processor must be installed.

## SSM Parameters

The script reads the following SSM parameters:

* `<json_attributes_parameter>`: SSM parameter containing a JSON object with the script input parameters
* `/arcgis/${site_id}/s3/backup`: S3 bucket for the backup
* `/arcgis/${site_id}/s3/region`: The S3 bucket region
