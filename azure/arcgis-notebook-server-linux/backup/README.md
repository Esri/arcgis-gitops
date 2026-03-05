# Backup Script for ArcGIS Notebook Server on Linux

The `exportSite.sh` script automates the process of backing up an ArcGIS Notebook Server deployment and securely storing the backup in the ArcGIS Enterprise site's backup blob storage (see [Back up and restore ArcGIS Notebook Server](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/back-up-and-restore-arcgis-notebook-server.htm)).

The script is designed to be executed by az_run_shell_script python module on the primary VM of the ArcGIS Notebook Server deployment. It uses Azure CLI commands to interact with Azure Blob Storage.

The script performs the following tasks:

* Sends a request to the server's [exportSite](https://developers.arcgis.com/rest/enterprise-administration/notebook/export-site-notebook-server/) endpoint to create a backup of the ArcGIS Notebook Server configuration store and save it to a specified staging location.
* Uploads the exported backup file from the staging location to the backup Azure Blob Storage container.
* Uploads the ArcGIS Notebook Server workspace directory to the backup Azure Blob Storage container.
* Deletes the backup file from the staging location.

## Requirements

On the machine where the script is executed:

* Azure CLI must be installed and available in the PATH.
* jq command-line JSON processor must be installed.
