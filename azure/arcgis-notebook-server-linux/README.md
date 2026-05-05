# ArcGIS Notebook Server on Linux Deployment in Microsoft Azure

This template provides GitHub Actions workflows for [ArcGIS Notebook Server deployment](https://enterprise.arcgis.com/en/notebook/) operations on Linux platforms.

Supported ArcGIS Notebook Server versions:

* 11.4
* 11.5
* 12.0

Supported Operating Systems:

* Red Hat Enterprise Linux 9
* Ubuntu 24.04 LTS

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Create core Azure resources and Chef automation resources for ArcGIS Enterprise using [arcgis-enterprise-core](../arcgis-enterprise-core/README.md) template.
3. Create a base ArcGIS Enterprise deployment using [arcgis-enterprise-base-linux](../arcgis-enterprise-base-linux/README.md) or [arcgis-enterprise-base-windows](../arcgis-enterprise-base-windows/README.md) templates.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of ArcGIS Notebook Server includes building images, provisioning Azure resources, configuring the applications, and testing the deployment web services.

### 1. Build Images

GitHub Actions workflow **notebook-server-linux-azure-image** creates Azure VM images for ArcGIS Notebook Server deployment.

The workflow uses: [image](image/README.md) Packer template with [image.vars.json](../../config/azure/arcgis-notebook-server-linux/image.vars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. (Optional) Set "arcgis_notebook_server_patches" and "arcgis_web_adaptor_patches" properties to the lists of patch file names that must be installed on the images.
2. (Optional) Set "gpu_ready" property to `true` to configure the VM to [use GPUs](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/configure-arcgis-notebook-server-to-use-gpus.htm). This also requires "vm_size" to be set to a VM size with GPU support in image.vars.json and infrastructure.tfvars.json config files.
3. Commit the changes to a Git branch and push the branch to GitHub.
4. Run the notebook-server-linux-azure-image workflow using the branch.

### 2. Provision Azure Resources

GitHub Actions workflow **notebook-server-linux-azure-infrastructure** creates Azure resources for ArcGIS Notebook Server deployment.

The workflow uses [infrastructure](infrastructure/README.md) Terraform template with [infrastructure.tfvars.json](../../config/azure/arcgis-notebook-server-linux/infrastructure.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Workflow Inputs:

* terraform_command - Terraform command (apply|plan)

Instructions:

1. If required, change "vm_size" and "os_disk_size" properties to the required VM size and OS disk size (in GB).
2. If required, change "portal_deployment_id" property to the deployment ID of Portal for ArcGIS the ArcGIS Notebook Server will be federated with.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run the notebook-server-linux-azure-infrastructure workflow using the branch.

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical Azure resources such as VMs.

### 3. Configure Applications

GitHub Actions workflow **notebook-server-linux-azure-application** configures or upgrades ArcGIS Notebook Server on Azure VMs.

The workflow uses [application](application/README.md) Terraform template with [application.tfvars.json](../../config/azure/arcgis-notebook-server-linux/application.tfvars.json) config file.

Required service principal roles:

* Contributor

Outputs:

* arcgis_notebook_server_url - ArcGIS Notebook Server URL

Instructions:

1. Add ArcGIS Notebook Server authorization file to `config/authorization/<ArcGIS version>` directory of the repository and set "notebook_server_authorization_file_path" property to the file path.
2. (Optionally) Add SSL trusted root certificates to `config/certificates` directory and set "root_cert_file_path" properties to the file path.
3. (Optionally) Set "config_store_type" to "AZURE" to use ArcGIS Notebook Server configuration store in Azure Storage account instead of Azure files network share.
4. Run the notebook-server-linux-azure-application workflow using the branch.

> '~/config/' path is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test ArcGIS Notebook Server Deployment

GitHub Actions workflow **notebook-server-linux-azure-test** tests ArcGIS Notebook Server deployment.

The workflow uses test-server-admin script from ArcGIS Enterprise Admin CLI to test access to the ArcGIS Notebook Server admin URL retrieved from Azure Key Vault.

Instructions:

1. Run the notebook-server-linux-azure-test workflow using the branch.

## Backups and Disaster Recovery

The template supports application-level ArcGIS Notebook Server backup and restore operations.

The application-level ArcGIS Notebook Server deployment backups back up and restore the site's configuration store using [Export Site and Import Site tools](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/back-up-and-restore-arcgis-notebook-server.htm) and the *arcgisworkspace* directory. The backups are stored in the site's backup Azure Blob Storage account.

### Creating Application-level Backups

GitHub Actions workflow **notebook-server-linux-azure-backup** creates ArcGIS Notebook Server backups.

The workflow uses [backup](backup/README.md) script with [backup.vars.json](../../config/azure/arcgis-notebook-server-linux/backup.vars.json) config file.

Required service principal roles:

* Contributor

Instructions:

1. Run the notebook-server-linux-azure-backup workflow using the main/default branch.

To meet the required recovery point objective (RPO), schedule runs of notebook-server-linux-azure-backup workflow by configuring 'schedule' event in notebook-server-linux-azure-backup.yaml file. Note that scheduled workflows run on the latest commit on the `main` (or default) branch.

### Restoring from Application-level Backups

GitHub Actions workflow **notebook-server-linux-azure-restore** restores ArcGIS Notebook Server from the latest backup.

The workflow uses [restore](restore/README.md) script with [restore.vars.json](../../config/azure/arcgis-notebook-server-linux/restore.vars.json) config file.

Required service principal roles:

* Contributor

Instructions:

1. Run the notebook-server-linux-azure-restore workflow using the main (default) branch.

## In-Place Updates and Upgrades

GitHub Actions workflow notebook-server-linux-azure-application supports upgrade mode used to patch or upgrade in place ArcGIS Notebook Server on the VMs. In the upgrade mode, the workflow copies the required patches and setups to the private repository blob store and downloads them to the VMs. If the ArcGIS Notebook Server version was changed, it installs the new version and re-configures the applications.

Instructions:

1. Set "arcgis_notebook_server_patches" and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the VMs.
2. Add ArcGIS Notebook Server authorization file for the new version to `config/authorization/<ArcGIS version>` directory of the repository and set "notebook_server_authorization_file_path" property in application.tfvars.json file to the file path.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the notebook-server-linux-azure-application workflow using the branch.

## Destroying Deployments

GitHub Actions workflow **notebook-server-linux-azure-destroy** destroys Azure resources created by notebook-server-linux-azure-image, notebook-server-linux-azure-infrastructure and notebook-server-linux-azure-application workflows.

The workflow uses [infrastructure](infrastructure/README.md) and [application](application/README.md) Terraform templates with [infrastructure.tfvars.json](../../config/azure/arcgis-notebook-server-linux/infrastructure.tfvars.json) and [application.tfvars.json](../../config/azure/arcgis-notebook-server-linux/application.tfvars.json) config files.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. Run the notebook-server-linux-azure-destroy workflow using the branch.

> notebook-server-linux-azure-destroy workflow does not delete the deployment's backups.

## Disconnected Environments

To prevent deployments from accessing the Internet, use "internal" subnets for VMs. The internal subnets do not have public IP addresses and are routed only to VNet endpoints of certain Azure services in a specific Azure region.

The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.

The application image builds run in "private" subnets that can access the internet. The image build installs Azure CLI, and packages required by the applications. The application update and upgrade workflows use Azure Blob Storage endpoint to access the private repository blob store to get all the required files.

The disconnected deployments must use authorization files that do not require internet access to the Esri license server, such as Esri Secure License File (ESLF) or ECP file (.ecp).  
