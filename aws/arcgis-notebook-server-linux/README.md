# ArcGIS Notebook Server on Linux Deployment in AWS

This template provides GitHub Actions workflows for [ArcGIS Notebook Server deployment](https://enterprise.arcgis.com/en/notebook/) operations on Linux platforms.

Supported ArcGIS Notebook Server versions:

* 11.4
* 11.5

Supported Operating Systems:

* Red Hat Enterprise Linux 9
* Ubuntu 24.04 LTS

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Create core AWS resources and Chef automation resources for ArcGIS Enterprise site using [arcgis-site-core](../arcgis-site-core/README.md) template.
3. Create a base ArcGIS Enterprise deployment using [arcgis-enterprise-base-linux](../arcgis-enterprise-base-linux/README.md) or [arcgis-enterprise-base-windows](../arcgis-enterprise-base-windows/) templates.

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
2. (Optional) Set "gpu_ready" property to `true` to configure the AMI to [use GPUs](https://enterprise.arcgis.com/en/notebook/latest/administer/linux/configure-arcgis-notebook-server-to-use-gpus.htm). This also requires requires "instance_type" to be set to an EC2 instance type with GPU support in image.vars.json and infrastructure.tfvars.json config files.
3. Commit the changes to a Git branch and push the branch to GitHub.
4. Run the notebook-server-linux-aws-image workflow using the branch.

> In the configuration files, "os" and "arcgis_version" properties values for the same deployment must match across all the configuration files of the deployment.

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
2. To add the deployment to the load balancer of a base ArcGIS Enterprise deployment, set "alb_deployment_id" property to the base deployment Id. Otherwise, set "deployment_fqdn" property to the ArcGIS Notebook Server deployment fully qualified domain name, provision or import SSL certificate for the domain name into AWS Certificate Manager service in the selected AWS region, and set "ssl_certificate_arn" property to the certificate ARN.
3. If required, change "instance_type" and "root_volume_size" properties to the required [EC2 instance type](https://aws.amazon.com/ec2/instance-types/) and root EBS volume size (in GB).
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run the notebook-server-linux-aws-infrastructure workflow using the branch.

### 3. Configure Applications

GitHub Actions workflow **notebook-server-linux-aws-application** configures or upgrades ArcGIS Notebook Server on EC2 instances.

The workflow uses [application](application/README.md) Terraform template with [application.tfvars.json](../../config/aws/arcgis-notebook-server-linux/application.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Inputs:

* terraform_command - Terraform command (apply|plan)

Outputs:

* arcgis_notebook_server_url - ArcGIS Notebook Server URL

Instructions:

1. Add ArcGIS Notebook Server authorization file to `config/authorization/<ArcGIS version>` directory of the repository and set "notebook_server_authorization_file_path" properties to the file path.
2. If the server does not share the load balancer with the base ArcGIS Enterprise deployment, set "portal_url" property to the Portal for ArcGIS URL.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run the notebook-server-linux-aws-application workflow using the branch.

> '~/config/' paths is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test ArcGIS Notebook Server Deployment

GitHub Actions workflow **notebook-server-linux-aws-test** tests ArcGIS Notebook Server deployment.

The workflow uses test-server-admin script from ArcGIS Enterprise Admin CLI to test access of the ArcGIS Notebook Server admin URL. The server domain name and web context are retrieved from infrastructure.tfvars.json properties file and from SSM parameters.

Instructions:

1. Run the notebook-server-linux-aws-test workflow using the branch.

## Backups and Disaster Recovery

The template supports application-level ArcGIS Notebook Server backup and restore operations.

### Create Backups

GitHub Actions workflow **notebook-server-linux-aws-backup** creates ArcGIS Notebook Server backups.

The workflow uses [backup](backup/README.md) script with [backup.vars.json](../../config/aws/arcgis-notebook-server-linux/backup.vars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Run the notebook-server-linux-aws-backup workflow using the main/default branch.

To meet the required recovery point objective (RPO), schedule runs of notebook-server-linux-aws-backup workflow by configuring 'schedule' event in notebook-server-linux-aws-backup.yaml file. Note that scheduled workflows run on the latest commit on the `main` (or default) branch.

### Restore from Backups

GitHub Actions workflow **notebook-server-linux-aws-restore** restores ArcGIS Notebook Server from backup.

The workflow uses [restore](restore/README.md) script with [restore.vars.json](../../config/aws/arcgis-notebook-server-linux/restore.vars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Run the notebook-server-linux-aws-restore workflow using the main/default branch.

### Create Snapshots and Restore from Snapshots

GitHub Actions workflow **notebook-server-linux-aws-snapshot** creates a system-level backup by creating AMIs from all EC2 instances of ArcGIS Notebook Server deployment. The workflow retrieves site and deployment IDs from [image.vars.json](../../config/aws/arcgis-notebook-server-linux/image.vars.json) config file and runs snapshot_deployment Python script. The workflow requires ArcGISEnterpriseImage IAM policy.

The workflows overwrites the AMI IDs in SSM Parameter Store written there by notebook-server-linux-aws-image workflow. When necessary, the deployment can be rolled back to state captured in the snapshot by running notebook-server-linux-aws-infrastructure workflow.

> Because all the node instances are restored from the same snapshot AMIs, the snapshots are supported only if node_count is set to either 0 or 1 in the infrastructure.tfvars.json config file.

> Running notebook-server-linux-aws-snapshot workflow causes a short downtime because it reboots the EC2 instances.

> The snapshot captures only the data on the EC2 instances that does not include the content of other storage services, such as arcgisworkspace directory that is stored in the EFS filesystem.

Since creating snapshots involves downtime and integrity of the data cannot be guaranteed if data in the storage services was updated after the snapshot creation, snapshots are not recommended for use as backups for active deployments. Snapshots should be created during planned downtime, after deactivating the deployment, and before applying system and application patches or other system-level updates.

> The snapshot creation time depends on the size and throughput of the root EBS volumes of the EC2 instances.

## In-Place Updates and Upgrades

GitHub Actions workflow notebook-server-linux-aws-application supports upgrade mode used to in-place patch or upgrade ArcGIS Notebook Server on the EC2 instances. In the upgrade mode, the workflow copies the required patches and setups to the private repository S3 bucket and downloads them to the EC2 instances. If the ArcGIS Notebook Server version was changed, it installs the new version and re-configures the applications.

Instructions:

1. Set "arcgis_notebook_server_patches" and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the EC2 instances.
2. Add ArcGIS Notebook Server authorization files for the new version to `config/authorization/<ArcGIS version>` directory of the repository and set "notebook_server_authorization_file_path" property in application.tfvars.json file to the file path.
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

To prevent deployments from accessing the Internet, use "internal" subnets for EC2 instances. The internal subnets do not have public IP addresses and are routed only to VPC endpoints of certain AWS services in specific AWS region.

The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.

The application image builds run in "private" subnets that can access the internet. The image build installs SSM Agents, CloudWatch agents, AWS CLI, and system packages required by the applications. The application update and upgrade workflows use S3 VPC endpoint to access the private repository S3 bucket to get all the required files.

The disconnected deployments must use authorization files that do not require internet access to the Esri license server, such as Esri Secure License File (ESLF) or ECP file (.ecp).  
