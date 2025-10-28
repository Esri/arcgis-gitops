# Base ArcGIS Enterprise on Windows Deployment in Azure

This template provides GitHub Actions workflows for [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm) operations on Windows platform.

Supported ArcGIS Enterprise versions:

* 11.4
* 11.5
  
Supported Operating Systems:

* Windows Server 2022
* Windows Server 2025

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Create core Azure resources, Chef automation resources, and Application Gateway for the ArcGIS Enterprise site using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of base ArcGIS Enterprise includes building images, provisioning Azure resources, configuring the applications, and testing the deployment web services.

### 1. Set GitHub Actions Secrets for the Site

Set the primary ArcGIS Enterprise site administrator, run as user, and VM administrator credentials in the GitHub Actions secrets of the repository settings.

| Name                      | Description                                    |
|---------------------------|------------------------------------------------|
| ENTERPRISE_ADMIN_USERNAME | ArcGIS Enterprise administrator user name      |
| ENTERPRISE_ADMIN_PASSWORD | ArcGIS Enterprise administrator user password  |
| ENTERPRISE_ADMIN_EMAIL    | ArcGIS Enterprise administrator e-mail address |
| RUN_AS_PASSWORD           | Password of 'arcgis' Windows user account      |
| VM_ADMIN_USERNAME         | Windows VM administrator user name             |
| VM_ADMIN_PASSWORD         | Windows VM administrator user password         |

> The ArcGIS Enterprise administrator user name must be between 6 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.).

> The ArcGIS Enterprise administrator user password must be between 8 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.).

> The password of 'arcgis' Windows user account must be at least 8 characters long, include at least three of the four character types: uppercase letters, lowercase letters, numbers, and special characters. Additionally, passwords should not contain the account name ('arcgis').

> The Windows VM administrator user password must be between 12 and 123 characters long and must have lowercase characters, uppercase characters, a digit, and a special character.

### 2. Build Images

GitHub Actions workflow **enterprise-base-windows-azure-image** creates VM image for base ArcGIS Enterprise deployment.

The workflow uses [image](image/README.md) Packer template with [image.vars.json](../../config/azure/arcgis-enterprise-base-windows/image.vars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties to the lists of patch file names that must be installed on the images.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run the enterprise-base-windows-azure-image workflow using the branch.

> In the configuration files, "os" and "arcgis_version" properties values for the same deployment must match across all the configuration files of the deployment.

### 3. Provision Azure Resources

GitHub Actions workflow **enterprise-base-windows-azure-infrastructure** creates Azure resources for base ArcGIS Enterprise deployment.

The workflow uses [infrastructure](infrastructure/README.md) Terraform template with [infrastructure.tfvars.json](../../config/azure/arcgis-enterprise-base-windows/infrastructure.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. If required, change "vm_size" and "os_disk_size" properties to the required VM size and OS disk size (in GB).
2. Commit the changes to the Git branch and push the branch to GitHub.
3. Run the enterprise-base-windows-azure-infrastructure workflow using the branch.

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical Azure resources such as VMs.

### 4. Configure Applications

GitHub Actions workflow **enterprise-base-windows-azure-application** configures or upgrades base ArcGIS Enterprise on the deployment VMs.

The workflow uses [application](application/README.md) Terraform template with [application.tfvars.json](../../config/azure/arcgis-enterprise-base-windows/application.tfvars.json) config file.

Required service principal roles:

* Contributor

Instructions:

1. Add Portal for ArcGIS and ArcGIS Server authorization files for the ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties to the file paths.
2. Set "admin_full_name", "admin_description", "security_question", and "security_question_answer" to the initial ArcGIS Enterprise administrator account properties.
3. Add SSL certificates for the base ArcGIS Enterprise domain name and (optionally) trusted root certificates to `config/certificates` directory and set "keystore_file_path" and "root_cert_file_path" properties to the file paths. Set "keystore_file_password" property to password of the keystore file.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the enterprise-base-windows-azure-application workflow using the branch.

### 5. Test Base ArcGIS Enterprise Deployment

GitHub Actions workflow **enterprise-base-windows-azure-test** tests base ArcGIS Enterprise deployment.

The workflow uses test-publish-csv script from ArcGIS Enterprise Admin CLI to publish a CSV file to the Portal for ArcGIS URL. The portal domain name and web context are retrieved from application.tfvars.json properties file.

Instructions:

1. Run the enterprise-base-windows-azure-test workflow using the branch.

## Backups and Disaster Recovery

The template supports application-level base ArcGIS Enterprise backup and restore operations using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/windows/create-web-gis-backup.htm) tool.

The application-level backup of base ArcGIS Enterprise deployment backups the portal items, services, and data using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/windows/create-web-gis-backup.htm) tool. The backups are stored in the "webgisdr-backups" blob container site's storage account.

### Creating Application-level Backups

GitHub Actions workflow **enterprise-base-windows-azure-backup** creates base ArcGIS Enterprise backups using WebGISDR utility.

The workflow uses [backup](backup/README.md) Terraform template with [backup.tfvars.json](../../config/azure/arcgis-enterprise-base-windows/backup.tfvars.json) config file.

Required service principal roles:

* Contributor

Instructions:

1. Run enterprise-base-windows-azure-backup workflow using the main/default branch.

To meet the required recovery point objective (RPO), schedule runs of enterprise-base-windows-azure-backup workflow by configuring 'schedule' event in enterprise-base-windows-azure-backup.yaml file. When the backup workflow is triggered manually, the backup-restore mode is specified by the workflow inputs. However, when the workflow is triggered on schedule, the backup-restore mode is retrieved from the backup.tfvars.json config file. Note that scheduled workflows run on the latest commit on the `main` (or default) branch.

### Restoring from Application-level Backups

GitHub Actions workflow **enterprise-base-windows-azure-restore** restores base ArcGIS Enterprise from backup using WebGISDR utility.

The workflow uses [restore](restore/README.md) Terraform template with [restore.tfvars.json](../../config/azure/arcgis-enterprise-base-windows/restore.tfvars.json) config file.

Required service principal roles:

* Contributor

Instructions:

1. Run enterprise-base-windows-azure-restore workflow using the main/default branch.

## In-Place Updates and Upgrades

GitHub Actions workflow enterprise-base-windows-azure-application supports upgrade mode used to in-place patch or upgrade the base ArcGIS Enterprise applications on the VMs. In the upgrade mode, the workflow copies the required patches and setups to the private repository blob storage and downloads them to the VMs. If the ArcGIS Enterprise version was changed, it installs the new version of the ArcGIS Enterprise applications and re-configures the applications.

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the VMs.
2. Add Portal for ArcGIS and ArcGIS Server authorization files for the new ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the enterprise-base-windows-azure-application workflow using the branch.

## Destroying Deployments

GitHub Actions workflow **enterprise-base-windows-azure-destroy** destroys Azure resources created by enterprise-base-windows-azure-image, enterprise-base-windows-azure-infrastructure and enterprise-base-windows-azure-application workflows.

The workflow uses [infrastructure](infrastructure/README.md) and [application](application/README.md) Terraform templates with [infrastructure.tfvars.json](../../config/azure/arcgis-enterprise-base-windows/infrastructure.tfvars.json) and [application.tfvars.json](../../config/azure/arcgis-enterprise-base-windows/application.tfvars.json) config files.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. Run the enterprise-base-windows-azure-destroy workflow using the branch.

> enterprise-base-windows-azure-destroy workflow does not delete the deployment's backups.

## Disconnected Environments

To prevent deployments from accessing the Internet, use "internal" subnets for VMs. The internal subnets do not have public IP addresses and are routed only to service endpoints of certain Azure services.

The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, and time services.

The application image builds run in "private" subnets that can access the internet. The image build installs the agents, Azure CLI, and system packages required by the applications. The application update and upgrade workflows use the storage account endpoints to access the private "repository" blob container in the site's storage account to get all the required files.

The disconnected deployments must use authorization files that do not require internet access to the Esri license server, such as Esri Secure License File (ESLF) or ECP file (.ecp).  
