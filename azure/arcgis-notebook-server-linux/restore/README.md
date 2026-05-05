# Restore Script for ArcGIS Notebook Server on Linux

The `importSite.sh` script automates the process of restoring an ArcGIS Notebook Server deployment from a backup stored in the ArcGIS Enterprise's backup blob storage (see [Back up and restore ArcGIS Notebook Server](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/back-up-and-restore-arcgis-notebook-server.htm)).

The script is designed to be executed by az_run_shell_script python module on the primary VM of the ArcGIS Notebook Server deployment. It uses Azure CLI commands to interact with Azure Blob Storage for backup storage.

The script performs the following tasks:

* Downloads the latest backup file from the backup Azure Blob Storage container to a local staging location.
* Sends a request to the server's [importSite](https://developers.arcgis.com/rest/enterprise-administration/notebook/import-site-notebook-server/) endpoint to restore the ArcGIS Notebook Server config store from the downloaded backup.
* Copies the ArcGIS Notebook Server workspace directory from the backup Azure Blob Storage container to the deployment's `arcgisworkspace` directory.
* Deletes the backup file from the staging location.

## Requirements

On the machine where the script is executed:

* Azure CLI must be installed and available in the PATH.
* jq command-line JSON processor must be installed.

The deployment VMs must have access to the storage account of the backup enterprise specified by the `backup_enterprise_id` input variable:

* The deployment VMs must have network-level access to the storage account endpoint of the backup enterprise.
* The user-assigned managed identity attached to the deployment virtual machines must have read access
  to the storage account of the backup enterprise.

<!-- BEGIN_TF_DOCS -->

<!-- END_TF_DOCS -->