# Base ArcGIS Enterprise on Linux Deployment in AWS

This template provides GitHub Actions workflows for [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/linux/base-arcgis-enterprise-deployment.htm) operations on Linux platforms.

Supported ArcGIS Enterprise versions:

* 11.4
* 11.5
* 12.0

Supported Operating Systems:

* Red Hat Enterprise Linux 9
* Ubuntu 22.04 LTS
* Ubuntu 24.04 LTS

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Create core AWS resources and Chef automation resources for ArcGIS Enterprise site using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of base ArcGIS Enterprise includes building images, provisioning AWS resources, configuring the applications, and testing the deployment web services.

![Base ArcGIS Enterprise on Linux Configuration Flow](./arcgis-enterprise-base-linux-flowchart.png)

### 1. Set GitHub Actions Secrets for the Site

Set the primary ArcGIS Enterprise site administrator credentials in the GitHub Actions secrets of the repository settings.

| Name                      | Description                                    |
|---------------------------|------------------------------------------------|
| ENTERPRISE_ADMIN_USERNAME | ArcGIS Enterprise administrator user name      |
| ENTERPRISE_ADMIN_PASSWORD | ArcGIS Enterprise administrator user password  |
| ENTERPRISE_ADMIN_EMAIL    | ArcGIS Enterprise administrator e-mail address |

> The ArcGIS Enterprise administrator user name must be between 6 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.).

> The ArcGIS Enterprise administrator user password must be between 8 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.).

### 2. Build Images

GitHub Actions workflow **enterprise-base-linux-aws-image** creates EC2 AMIs for base ArcGIS Enterprise deployment.

The workflow uses: [image](image/README.md) Packer template with [image.vars.json](../../config/aws/arcgis-enterprise-base-linux/image.vars.json) config file.

Required IAM policies:

* ArcGISEnterpriseImage

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties to the lists of patch file names that must be installed on the images.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run enterprise-base-linux-aws-image workflow using the branch.

> In the configuration files, "os" and "arcgis_version" properties values for the same deployment must match across all the configuration files of the deployment.

### 3. Provision AWS Resources

GitHub Actions workflow **enterprise-base-linux-aws-infrastructure** creates AWS resources for base ArcGIS Enterprise deployment.

The workflow uses [infrastructure](infrastructure/README.md) Terraform template with [infrastructure.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/infrastructure.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseInfrastructure

Workflow Inputs:

* terraform_command - Terraform command (apply|plan)

Workflow Outputs:

* alb_dns_name - DNS name of the application load balancer

Instructions:

1. Create an EC2 key pair in the selected AWS region and set "key_name" property in the config file to the key pair name. Save the private key in a secure location.
2. Provision or import SSL certificate for the base ArcGIS Enterprise domain name into AWS Certificate Manager service in the selected AWS region and set "ssl_certificate_arn" property to the certificate ARN.
3. Set "deployment_fqdn" property to the base ArcGIS Enterprise deployment fully qualified domain name.
4. If required, change "instance_type" and "root_volume_size" properties to the required [EC2 instance type](https://aws.amazon.com/ec2/instance-types/) and root EBS volume size (in GB).
5. Commit the changes to the Git branch and push the branch to GitHub.
6. Run enterprise-base-linux-aws-infrastructure workflow using the branch.
7. Retrieve the DNS name of the load balancer created by the workflow and create a CNAME record for it within the DNS server of the base ArcGIS Enterprise domain name.

> Job outputs are not shown in the properties of completed GitHub Actions run. To retrieve the DNS name, check the run logs of "Terraform Apply" step or read it from "/arcgis/${var.site_id}/${var.deployment_id}/alb/dns-name" SSM parameter.

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical AWS resources such as EC2 instances.

### 4. Configure Applications

GitHub Actions workflow **enterprise-base-linux-aws-application** configures or upgrades base ArcGIS Enterprise on EC2 instances.

The workflow uses [application](application/README.md) Terraform template with [application.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/application.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Outputs:

* arcgis_portal_url - Portal for ArcGIS URL

Instructions:

1. Add Portal for ArcGIS and ArcGIS Server authorization files for the ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties to the file paths.
2. Set "admin_full_name", "admin_description", "security_question", and "security_question_answer" to the initial ArcGIS Enterprise administrator account properties.
3. (Optionally) Add SSL certificates for the base ArcGIS Enterprise domain name and trusted root certificates to `config/certificates` directory and set "keystore_file_path" and "root_cert_file_path" properties to the file paths. Set "keystore_file_password" property to password of the keystore file.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run enterprise-base-linux-aws-application workflow using the branch.

> Starting with ArcGIS Enterprise 12.0, "config_store_type" property can be set to "AMAZON" to configure the ArcGIS Server site to use Amazon DynamoDB as the configuration store, S3 as the object store and server directories, and SQS for GeoProcessing service queues, instead of using the EFS file system.

> '~/config/' paths is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 5. Test Base ArcGIS Enterprise Deployment

GitHub Actions workflow **enterprise-base-linux-aws-test** tests base ArcGIS Enterprise deployment.

The workflow uses test-publish-csv script from ArcGIS Enterprise Admin CLI to publish a CSV file to the Portal for ArcGIS URL. The portal domain name and web context are retrieved from infrastructure.tfvars.json properties file.

Instructions:

1. Run enterprise-base-linux-aws-test workflow using the branch.

## Backups and Disaster Recovery

The template supports:

* Application-level base ArcGIS Enterprise backup and restore operations using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/linux/create-web-gis-backup.htm) tool.
* System-level backup and recovery using [AWS Backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html) service.

### Application-level Backups

The application-level base ArcGIS Enterprise deployment backups back up the portal items, services, and data using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/linux/create-web-gis-backup.htm) tool. The backups are stored in the site's backup S3 bucket.

#### Creating Application-level Backups

GitHub Actions workflow **enterprise-base-linux-aws-backup** creates base ArcGIS Enterprise backups using WebGISDR utility.

The workflow uses [backup](backup/README.md) Terraform template with [backup.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/backup.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Run enterprise-base-linux-aws-backup workflow using the main/default branch.

To meet the required recovery point objective (RPO), schedule runs of enterprise-base-linux-aws-backup workflow by configuring 'schedule' event in enterprise-base-linux-aws-backup.yaml file. When the backup workflow is triggered manually, the backup-restore mode is specified by the workflow inputs. However, when the workflow is triggered on schedule, the backup-restore mode is retrieved from the backup.tfvars.json config file. Note that scheduled workflows run on the latest commit on the `main` (or default) branch.

> Base ArcGIS Enterprise deployments in a site use the same S3 bucket for backups. Run backups only for the active deployment branch.

#### Restoring from Application-level Backups

GitHub Actions workflow **enterprise-base-linux-aws-restore** restores base ArcGIS Enterprise from backup using WebGISDR utility.

The workflow uses [restore](restore/README.md) Terraform template with [restore.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/restore.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Run enterprise-base-linux-aws-restore workflow using the main/default branch.

### System-level backups

The system-level base ArcGIS Enterprise deployment backups back up S3 buckets, DynamoDB tables, EFS file systems, and EC2 instances of the deployment using [AWS Backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html) service. The backups are stored in the site's AWS Backup vault. These backups can be used to restore the entire deployment in case of a disaster.

> System-level backups do not guarantee application consistency. This means that while the recovery system will often be successfully restored and operated, in some cases application level inconsistencies could occur, i.e. a publishing process that is underway or a edit to a feature service that is made during the backup process.

#### Creating System-level Backups

GitHub Actions workflow **enterprise-base-linux-aws-infrastructure** creates an AWS backup plan for the deployment that backs up the EC2 instances, Portal for ArcGIS content store S3 bucket, ArcGIS Server object store S3 bucket, and the EFS file system created by the workflow in the site's AWS Backup vault. The backup schedule is controlled by the CRON expression set in the "backup_schedule" property in the [infrastructure.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/infrastructure.tfvars.json) file.

If the deployment uses S3 and DynamoDB AWS storage services for ArcGIS Server configuration store, then the GitHub Actions workflow **enterprise-base-linux-aws-application** enables versioning for the configuration store S3 bucket, tags the S3 bucket and DynamoDB table, and adds them to the deployment's backup plan.

The backup schedule is configured by a [CRON expression](https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html#cron-based) specified by the "backup_schedule" property and the number of days to retain backups is specified by the "backup_retention" property in [infrastructure.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/infrastructure.tfvars.json) config file.

#### Restoring from System-level Backups

GitHub Actions workflow **enterprise-base-linux-aws-recover** restores the entire deployment from the system-level backup.

The workflow:

1. Runs [recover_deployment](../scripts/README.md#recover_deployment) python script with [recover.vars.json](../../config/aws/arcgis-enterprise-base-linux/recover.vars.json) config file.
2. Runs [infrastructure](infrastructure/README.md) Terraform template with [infrastructure.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/infrastructure.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseInfrastructure

Instructions:

1. Run enterprise-base-linux-aws-recover workflow using the main/default branch.

> If "backup_time" property in recover.vars.json config file is set to `null`, the workflow will restore from the most recent backup. The "backup_time" property can be set to a backup timestamp in ISO 8601 format to restore from recovery points that were created before the specified timestamp.

> If the "test_mode" workflow input parameter is checked, the workflow will run in test mode and will not modify any resources.

> The system-level restoring process replaces the current state of the deployment with the state captured by the backup of that same deployment. Restoring to a new deployment is not supported because it requires additional manual steps to update the configuration files in the EC2 instances to use the S3 buckets and IP addresses of the new deployment.

## In-Place Updates and Upgrades

GitHub Actions workflow enterprise-base-linux-aws-application supports upgrade mode used to patch or upgrade in place the base ArcGIS Enterprise applications on the EC2 instances. In the upgrade mode, the workflow copies the required patches and setups to the private repository S3 bucket and downloads them to the EC2 instances. If the ArcGIS Enterprise version was changed, it installs the new version of the ArcGIS Enterprise applications and re-configures the applications.

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the EC2 instances.
2. Add Portal for ArcGIS and ArcGIS Server authorization files for the new ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run enterprise-base-linux-aws-application workflow using the branch.

## Destroying Deployments

GitHub Actions workflow **enterprise-base-linux-aws-destroy** destroys AWS resources created by enterprise-base-linux-aws-image, enterprise-base-linux-aws-infrastructure and enterprise-base-linux-aws-application workflows.

The workflow uses [infrastructure](infrastructure/README.md) and [application](application/README.md) Terraform templates with [infrastructure.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/infrastructure.tfvars.json) and [application.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/application.tfvars.json) config files.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseDestroy

Instructions:

1. Run enterprise-base-linux-aws-destroy workflow using the branch.

> enterprise-base-linux-aws-destroy workflow does not delete the deployment's backups.

## Disconnected Environments

To prevent deployments from accessing the Internet, use "internal" subnets for EC2 instances. The internal subnets do not have public IP addresses and are routed only to VPC endpoints of certain AWS services in specific AWS region.

The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.

The application image builds run in "private" subnets that can access the internet. The image build installs SSM Agents, CloudWatch agents, AWS CLI, and system packages required by the applications. The application update and upgrade workflows use S3 VPC endpoint to access the private repository S3 bucket to get all the required files.

The disconnected deployments must use authorization files that do not require internet access to the Esri license server, such as Esri Secure License File (ESLF) or ECP file (.ecp).  
