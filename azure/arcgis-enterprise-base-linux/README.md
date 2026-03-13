# Base ArcGIS Enterprise on Linux Deployment in Azure

This template provides GitHub Actions workflows for [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/linux/base-arcgis-enterprise-deployment.htm) operations on Linux platform.

Supported ArcGIS Enterprise versions:

* 11.4
* 11.5
* 12.0
  
Supported Operating Systems:

* Red Hat Enterprise Linux 9
* Ubuntu 24.04 LTS

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Create core Azure resources, Chef automation resources, and Application Gateway for the ArcGIS Enterprise site using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of base ArcGIS Enterprise includes building images, provisioning Azure resources, configuring the applications, and testing the deployment web services.

### 1. Set GitHub Actions Secrets for the Site

Set the primary ArcGIS Enterprise site administrator and VM administrator credentials in the GitHub Actions secrets of the repository settings.

| Name                      | Description                                    |
|---------------------------|------------------------------------------------|
| ENTERPRISE_ADMIN_USERNAME | ArcGIS Enterprise administrator user name      |
| ENTERPRISE_ADMIN_PASSWORD | ArcGIS Enterprise administrator user password  |
| VM_ADMIN_USERNAME         | Linux VM administrator user name               |
| VM_ADMIN_PASSWORD         | Linux VM administrator user password           |

> The ArcGIS Enterprise administrator user name must be between 6 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.).

> The ArcGIS Enterprise administrator user password must be between 8 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.).

> The Linux VM administrator user password must be between 12 and 123 characters long and must have lowercase characters, uppercase characters, a digit, and a special character.

### 2. Build Images

GitHub Actions workflow **enterprise-base-linux-azure-image** creates VM images for base ArcGIS Enterprise deployment on Linux.

The workflow uses [image](image/README.md) Packer template with [image.vars.json](../../config/azure/arcgis-enterprise-base-linux/image.vars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. Set the `arcgis_version`, `os`, and other properties in the [image.vars.json](../../config/azure/arcgis-enterprise-base-linux/image.vars.json) config file.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run the enterprise-base-linux-azure-image workflow.

> My Esri credentials (ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD) must be configured in GitHub Actions secrets to download ArcGIS Enterprise installation media from My Esri.

### 3. Provision Azure Resources

GitHub Actions workflow **enterprise-base-linux-azure-infrastructure** provisions Azure resources required for base ArcGIS Enterprise deployment on Linux.

The workflow uses [infrastructure](infrastructure/README.md) Terraform module with [infrastructure.tfvars.json](../../config/azure/arcgis-enterprise-base-linux/infrastructure.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope
* Storage Blob Data Contributor role on the Terraform state storage account

Instructions:

1. If required, set the `vm_size`, `os_disk_size`, `fileserver_size`, and other properties.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run the enterprise-base-linux-azure-infrastructure workflow.

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical Azure resources such as VMs.

### 4. Configure ArcGIS Enterprise Applications

GitHub Actions workflow **enterprise-base-linux-azure-application** installs and configures base ArcGIS Enterprise applications on Linux VMs.

The workflow uses [application](application/README.md) Terraform module with [application.tfvars.json](../../config/azure/arcgis-enterprise-base-linux/application.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope
* Storage Blob Data Contributor role on the Terraform state storage account

Instructions:

1. Add Portal for ArcGIS and ArcGIS Server authorization files for the ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties to the file paths.
2. Set "admin_full_name", "admin_description", "security_question_index", and "security_question_answer" to the initial ArcGIS Enterprise administrator account properties.
3. Add SSL certificates for the base ArcGIS Enterprise domain name and (optionally) trusted root certificates to `config/certificates` directory and set "keystore_file_path" and "root_cert_file_path" properties to the file paths. Set "keystore_file_password" property to password of the keystore file.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the enterprise-base-linux-azure-application workflow using the branch.

> Starting with ArcGIS Enterprise 12.0, for highly-available deployments, "config_store_type" property can be set to "AZURE" to configure the ArcGIS Server site to use Azure Cosmos DB as the configuration store, Azure Blob Storage as the object store and server directories, and Azure Service Bus for GeoProcessing service queues, instead of relying on the network file shares.

> '~/config/' path is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 5. Test the Deployment

GitHub Actions workflow **enterprise-base-linux-azure-test** tests the base ArcGIS Enterprise deployment by publishing a CSV file.

Instructions:

1. Run the enterprise-base-linux-azure-test workflow.

## Upgrade

To upgrade base ArcGIS Enterprise to a newer version:

1. Build new VM images for the new ArcGIS Enterprise version by updating `arcgis_version` and `os` properties in [image.vars.json](../../config/azure/arcgis-enterprise-base-linux/image.vars.json) and running the **enterprise-base-linux-azure-image** workflow.
2. In [infrastructure.tfvars.json](../../config/azure/arcgis-enterprise-base-linux/infrastructure.tfvars.json), verify that the `deployment_id` and `site_id` match the existing deployment.
3. Run the **enterprise-base-linux-azure-infrastructure** workflow to replace the VMs with new images.
4. Update `arcgis_version` and set `is_upgrade` to `true` in [application.tfvars.json](../../config/azure/arcgis-enterprise-base-linux/application.tfvars.json).
5. Run the enterprise-base-linux-azure-application workflow.

## Backup and Restore

The template supports application-level base ArcGIS Enterprise backup and restore operations using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/linux/create-web-gis-backup.htm) tool.

The application-level backup of base ArcGIS Enterprise deployment backs up the portal items, services, and data using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/linux/create-web-gis-backup.htm) tool. The backups are stored in the "webgisdr-backups" blob container in the site's storage account.

### Backup

GitHub Actions workflow **enterprise-base-linux-azure-backup** creates a WebGIS DR backup of the base ArcGIS Enterprise deployment.

The workflow uses [backup](backup/README.md) Terraform module with [backup.tfvars.json](../../config/azure/arcgis-enterprise-base-linux/backup.tfvars.json) config file.

Instructions:

1. Configure the `backup_restore_mode` and other properties.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run the enterprise-base-linux-azure-backup workflow.

### Restore

GitHub Actions workflow **enterprise-base-linux-azure-restore** restores a base ArcGIS Enterprise deployment from a WebGIS DR backup.

The workflow uses [restore](restore/README.md) Terraform module with [restore.tfvars.json](../../config/azure/arcgis-enterprise-base-linux/restore.tfvars.json) config file.

Instructions:

1. Configure the `backup_site_id`, `backup_restore_mode`, and other properties.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run the enterprise-base-linux-azure-restore workflow.

## In-Place Updates and Upgrades

GitHub Actions workflow enterprise-base-linux-azure-application supports an upgrade mode to patch or upgrade the base ArcGIS Enterprise applications in place on the VMs. In the upgrade mode, the workflow copies the required patches and setups to the private repository blob storage and downloads them to the VMs. If the ArcGIS Enterprise version was changed, it installs the new version of the ArcGIS Enterprise applications and re-configures the applications.

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the VMs.
2. Add Portal for ArcGIS and ArcGIS Server authorization files for the new ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the enterprise-base-linux-azure-application workflow using the branch.

## Destroy Deployment

GitHub Actions workflow **enterprise-base-linux-azure-destroy** destroys the base ArcGIS Enterprise deployment on Linux, including all Azure resources provisioned by the infrastructure module and the VM images built by the image Packer template.

Instructions:

1. Run the **enterprise-base-linux-azure-destroy** workflow.
