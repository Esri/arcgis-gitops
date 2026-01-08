# ArcGIS Notebook Server on Linux Deployment in AWS

This template provides GitHub Actions workflows for [ArcGIS Notebook Server deployment](https://enterprise.arcgis.com/en/notebook/) operations on Linux platforms.

Supported ArcGIS Notebook Server versions:

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
3. Create a base ArcGIS Enterprise deployment using [arcgis-enterprise-base-linux](../arcgis-enterprise-base-linux/README.md) or [arcgis-enterprise-base-windows](../arcgis-enterprise-base-windows/README.md) templates.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of ArcGIS Notebook Server includes building images, provisioning AWS resources, configuring the applications, and testing the deployment web services.

### 1. Build Images

GitHub Actions workflow **notebook-server-linux-aws-image** creates EC2 AMIs for ArcGIS Notebook Server deployment.

The workflow uses: [image](image/README.md) Packer template with [image.vars.json](../../config/aws/arcgis-notebook-server-linux/image.vars.json) config file.

Required IAM policies:

* ArcGISEnterpriseImage

Instructions:

1. (Optional) Set "arcgis_notebook_server_patches" and "arcgis_web_adaptor_patches" properties to the lists of patch file names that must be installed on the images.
2. (Optional) Set "gpu_ready" property to `true` to configure the AMI to [use GPUs](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/configure-arcgis-notebook-server-to-use-gpus.htm). This also requires "instance_type" to be set to an EC2 instance type with GPU support in image.vars.json and infrastructure.tfvars.json config files.
3. Commit the changes to a Git branch and push the branch to GitHub.
4. Run the notebook-server-linux-aws-image workflow using the branch.

> In the configuration files, "os" and "arcgis_version" property values for the same deployment must match across all the configuration files of the deployment.

### 2. Provision AWS Resources

GitHub Actions workflow **notebook-server-linux-aws-infrastructure** creates AWS resources for ArcGIS Notebook Server deployment.

The workflow uses [infrastructure](infrastructure/README.md) Terraform template with [infrastructure.tfvars.json](../../config/aws/arcgis-notebook-server-linux/infrastructure.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseInfrastructure

Workflow Inputs:

* terraform_command - Terraform command (apply|plan)

Workflow Outputs:

* alb_dns_name - DNS name of the application load balancer

Instructions:

1. Create an EC2 key pair in the selected AWS region and set "key_name" property in the config file to the key pair name. Save the private key in a secure location.
2. To add the deployment to the load balancer of a base ArcGIS Enterprise deployment, set "alb_deployment_id" property to the base deployment ID. Otherwise, set "deployment_fqdn" property to the ArcGIS Notebook Server deployment fully qualified domain name, provision or import an SSL certificate for the domain name into AWS Certificate Manager service in the selected AWS region, and set "ssl_certificate_arn" property to the certificate ARN.
3. If required, change "instance_type" and "root_volume_size" properties to the required [EC2 instance type](https://aws.amazon.com/ec2/instance-types/) and root EBS volume size (in GB).
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the notebook-server-linux-aws-infrastructure workflow using the branch.

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical AWS resources such as EC2 instances.

### 3. Configure Applications

GitHub Actions workflow **notebook-server-linux-aws-application** configures or upgrades ArcGIS Notebook Server on EC2 instances.

The workflow uses [application](application/README.md) Terraform template with [application.tfvars.json](../../config/aws/arcgis-notebook-server-linux/application.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Outputs:

* arcgis_notebook_server_url - ArcGIS Notebook Server URL

Instructions:

1. Add ArcGIS Notebook Server authorization file to `config/authorization/<ArcGIS version>` directory of the repository and set "notebook_server_authorization_file_path" property to the file path.
2. If the server does not share the load balancer with the base ArcGIS Enterprise deployment, set "portal_url" property to the Portal for ArcGIS URL.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run the notebook-server-linux-aws-application workflow using the branch.

> '~/config/' path is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test ArcGIS Notebook Server Deployment

GitHub Actions workflow **notebook-server-linux-aws-test** tests ArcGIS Notebook Server deployment.

The workflow uses test-server-admin script from ArcGIS Enterprise Admin CLI to test access of the ArcGIS Notebook Server admin URL. The server domain name and web context are retrieved from infrastructure.tfvars.json properties file and from SSM parameters.

Instructions:

1. Run the notebook-server-linux-aws-test workflow using the branch.

## Backups and Disaster Recovery

The template supports application-level and system-level ArcGIS Notebook Server backup and restore operations.

### Application-level Backups

The application-level ArcGIS Notebook Server deployment backups back up and restore the site's configuration store using [Export Site and Import Site tools](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/back-up-and-restore-arcgis-notebook-server.htm) and the *arcgisworkspace* directory. The backups are stored in the site's backup S3 bucket.

#### Creating Application-level Backups

GitHub Actions workflow **notebook-server-linux-aws-backup** creates ArcGIS Notebook Server backups.

The workflow uses [backup](backup/README.md) script with [backup.vars.json](../../config/aws/arcgis-notebook-server-linux/backup.vars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Run the notebook-server-linux-aws-backup workflow using the main/default branch.

To meet the required recovery point objective (RPO), schedule runs of notebook-server-linux-aws-backup workflow by configuring 'schedule' event in notebook-server-linux-aws-backup.yaml file. Note that scheduled workflows run on the latest commit on the `main` (or default) branch.

#### Restoring from Application-level Backups

GitHub Actions workflow **notebook-server-linux-aws-restore** restores ArcGIS Notebook Server from backup.

The workflow uses [restore](restore/README.md) script with [restore.vars.json](../../config/aws/arcgis-notebook-server-linux/restore.vars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Run the notebook-server-linux-aws-restore workflow using the main/default branch.

### System-level backups

The system-level ArcGIS Notebook Server deployment backups back up S3 buckets, DynamoDB tables, EFS file systems, and EC2 instances of the deployment using [AWS Backup](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html) service. The backups are stored in the site's AWS Backup vault. These backups can be used to restore the entire deployment in case of a disaster.

> System-level backups do not guarantee application consistency. This means that while the recovery system will often be successfully restored and operated, in some cases application level inconsistencies could occur, i.e. a publishing process that is underway or an edit to a feature service that is made during the backup process.

#### Creating System-level Backups

GitHub Actions workflow **notebook-server-linux-aws-infrastructure** creates an AWS backup plan for the deployment that backs up the EC2 instances and the EFS file system created by the workflow in the site's AWS Backup vault. The backup schedule is controlled by the CRON expression set in the "backup_schedule" property in the [infrastructure.tfvars.json](../../config/aws/arcgis-notebook-server-linux/infrastructure.tfvars.json) file.

If the deployment uses S3 and DynamoDB AWS storage services for ArcGIS Notebook Server configuration store, then the GitHub Actions workflow **notebook-server-linux-aws-application** enables versioning for the configuration store S3 bucket, tags the S3 bucket and DynamoDB table, and adds them to the deployment's backup plan.

The backup schedule is configured by a [CRON expression](https://docs.aws.amazon.com/scheduler/latest/UserGuide/schedule-types.html#cron-based) specified by the "backup_schedule" property and the number of days to retain backups is specified by the "backup_retention" property in [infrastructure.tfvars.json](../../config/aws/arcgis-notebook-server-linux/infrastructure.tfvars.json) config file.

#### Restoring from System-level Backups

GitHub Actions workflow **notebook-server-linux-aws-recover** restores the entire deployment from the system-level backup.

The workflow:

1. Runs [recover_deployment](../scripts/README.md#recover_deployment) python script with [recover.vars.json](../../config/aws/arcgis-notebook-server-linux/recover.vars.json) config file.
2. Runs [infrastructure](infrastructure/README.md) Terraform template with [infrastructure.tfvars.json](../../config/aws/arcgis-notebook-server-linux/infrastructure.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseInfrastructure

Instructions:

1. Run notebook-server-linux-aws-recover workflow using the main/default branch.

> If "backup_time" property in recover.vars.json config file is set to `null`, the workflow will restore from the most recent backup. The "backup_time" property can be set to a backup timestamp in ISO 8601 format to restore from recovery points that were created before the specified timestamp.

> If the "test_mode" workflow input parameter is checked, the workflow will run in test mode and will not modify any resources.

## In-Place Updates and Upgrades

GitHub Actions workflow notebook-server-linux-aws-application supports upgrade mode used to patch or upgrade in place ArcGIS Notebook Server on the EC2 instances. In the upgrade mode, the workflow copies the required patches and setups to the private repository S3 bucket and downloads them to the EC2 instances. If the ArcGIS Notebook Server version was changed, it installs the new version and re-configures the applications.

Instructions:

1. Set "arcgis_notebook_server_patches" and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the EC2 instances.
2. Add ArcGIS Notebook Server authorization file for the new version to `config/authorization/<ArcGIS version>` directory of the repository and set "notebook_server_authorization_file_path" property in application.tfvars.json file to the file path.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the notebook-server-linux-aws-application workflow using the branch.

## Destroying Deployments

GitHub Actions workflow **notebook-server-linux-aws-destroy** destroys AWS resources created by notebook-server-linux-aws-image, notebook-server-linux-aws-snapshot, notebook-server-linux-aws-infrastructure and notebook-server-linux-aws-application workflows.

The workflow uses [infrastructure](infrastructure/README.md) and [application](application/README.md) Terraform templates with [infrastructure.tfvars.json](../../config/aws/arcgis-notebook-server-linux/infrastructure.tfvars.json) and [application.tfvars.json](../../config/aws/arcgis-notebook-server-linux/application.tfvars.json) config files.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseDestroy

Instructions:

1. Run the notebook-server-linux-aws-destroy workflow using the branch.

> notebook-server-linux-aws-destroy workflow does not delete the deployment's backups.

## Disconnected Environments

To prevent deployments from accessing the Internet, use "internal" subnets for EC2 instances. The internal subnets do not have public IP addresses and are routed only to VPC endpoints of certain AWS services in a specific AWS region.

The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.

The application image builds run in "private" subnets that can access the internet. The image build installs SSM Agents, CloudWatch agents, AWS CLI, and system packages required by the applications. The application update and upgrade workflows use S3 VPC endpoint to access the private repository S3 bucket to get all the required files.

The disconnected deployments must use authorization files that do not require internet access to the Esri license server, such as Esri Secure License File (ESLF) or ECP file (.ecp).  
