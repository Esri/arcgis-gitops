# Base ArcGIS Enterprise on Linux Deployment in AWS

The template provides GitHub Actions workflows for [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm) operations on Linux platforms.

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Provision core AWS resources for ArcGIS Enterprise site using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of base ArcGIS Enterprise includes: building images, provisioning AWS resources, configuring the applications, and testing the deployment web services.

### 1. Build Images

GitHub Actions workflow **enterprise-base-linux-aws-image** creates EC2 AMIs for base ArcGIS Enterprise deployment.

The workflow uses: [image](image/README.md) Packer template with [image.vars.json](../../config/aws/arcgis-enterprise-base-linux/image.vars.json) config file.

Required IAM policies:

* ArcGISEnterpriseImage

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in image.vars.json file to the lists of patch file names that must be installed on the images.
2. Commit the changes to a Git branch and push the branch to GitHub.
3. Run enterprise-base-linux-aws-image workflow using the branch.

> In the configuration files, "os" and "arcgis_version" properties values for the same deployment must match across all the configuration files of the deployment.

### 2. Provision AWS Resources

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

1. Create an EC2 key pair in the selected AWS region and set "key_name" property in infrastructure.tfvars.json file to the key pair name. Save the private key in a secure location.
2. Provision or import SSL certificate for the base ArcGIS Enterprise domain name into AWS Certificate Manager service in the selected AWS region and set "ssl_certificate_arn" property in infrastructure.tfvars.json file to the certificate ARN.
3. If required, change "instance_type" and "root_volume_size" properties in infrastructure.tfvars.json file to the required [EC2 instance type](https://aws.amazon.com/ec2/instance-types/) and root EBS volume size (in GB).
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run enterprise-base-linux-aws-infrastructure workflow using the branch.
6. Retrieve the DNS name of the load balancer created by the workflow and create a CNAME record for it within the DNS server of the base ArcGIS Enterprise domain name.

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical AWS resources such as EC2 instances.

### 3. Configure Applications

GitHub Actions workflow **enterprise-base-linux-aws-application** configures or upgrades base ArcGIS Enterprise on EC2 instances.

The workflow uses [application](application/README.md) Terraform template with [application.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/application.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Inputs:

* terraform_command - Terraform command (apply|plan)

Outputs:

* arcgis_portal_url - Portal for ArcGIS URL

Instructions:

1. Add Portal for ArcGIS and ArcGIS Server authorization files for the ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths.
2. Set "domain_name" property in application.tfvars.json file to the base ArcGIS Enterprise deployment domain name.
3. Set "admin_username", "admin_password", "admin_full_name", "admin_description", "admin_email", "security_question", and "security_question_answer" in application.tfvars.json file to the initial ArcGIS Enterprise administrator account properties.
4. (Optionally) Add SSL certificates for the base ArcGIS Enterprise domain name and trusted root certificates to `config/certificates` directory and set "keystore_file_path" and "root_cert_file_path" properties in application.tfvars.json file to the file paths. Set "keystore_file_password" property to password of the keystore file.
5. Commit the changes to the Git branch and push the branch to GitHub.
6. Run enterprise-base-linux-aws-application workflow using the branch.

> '~/config/' paths is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test Base ArcGIS Enterprise Deployment

GitHub Actions workflow **enterprise-base-linux-aws-test** tests base ArcGIS Enterprise deployment.

The python [test script](../tests/arcgis-enterprise-base-test.py) uses [ArcGIS API for Python](https://developers.arcgis.com/python/) to publish a CSV file to the Portal for ArcGIS URL. The portal domain name and admin credentials are retrieved from application.tfvars.json properties file.

Instructions:

1. Run enterprise-base-linux-aws-test workflow using the branch.

## Backups and Disaster Recovery

The templates support application-level base ArcGIS Enterprise backup and restore operations using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/windows/create-web-gis-backup.htm) tool across multiple deployments.

### Create Backups

GitHub Actions workflow **enterprise-base-linux-aws-backup** creates base ArcGIS Enterprise backups using WebGISDR utility.

The workflow uses [backup](backup/README.md) Terraform template with [backup.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/backup.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Set "admin_username" and "admin_password" properties in backup.tfvars.json file to the portal administrator user name and password respectively.
2. Commit the changes to the Git branch and push the branch to GitHub.
3. Run enterprise-base-linux-aws-backup workflow using the branch.

> To meet the required recovery point objective (RPO), schedule runs of enterprise-base-linux-aws-backup workflow by configuring 'schedule' event in enterprise-base-linux-aws-backup.yml file.

> Base ArcGIS Enterprise deployments in a site use the same S3 bucket for backups. Run backups only for the active deployment branch.

### Restore from Backups

GitHub Actions workflow **enterprise-base-linux-aws-restore** restores base ArcGIS Enterprise from backup using WebGISDR utility.

The workflow uses [restore](restore/README.md) Terraform template with [restore.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/restore.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Set "admin_username" and "admin_password" properties in restore.tfvars.json file to the portal administrator user name and password respectively.
2. Commit the changes to the Git branch and push the branch to GitHub.
3. Run enterprise-base-linux-aws-restore workflow using the branch.

### Failover Deployment

One common approach to responding to a disaster scenario is to switch traffic to a failover deployment, which exists to take on traffic when a primary deployment identifies or experiences issues.

To create failover deployment:

1. Create a new Git branch from the branch of the active deployment.
2. Change "deployment_id" property in all the configuration files (image.vars.json, infrastructure.tfvars.json, application.tfvars.json, backup.tfvars.json, restore.tfvars.json) to a new unique Id of the failover deployment.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-base-linux-aws-backup workflow for the active deployment branch.
5. Run the following workflows for the failover deployment branch:
   1. enterprise-base-linux-aws-image
   2. enterprise-base-linux-aws-infrastructure
   3. enterprise-base-linux-aws-application
   4. enterprise-base-linux-aws-restore

To activate the failover deployment:

1. Retrieve DNS name of the load balancer created by the infrastructure workflow, and
2. Update the CNAME record for the base ArcGIS Enterprise domain name in the DNS server.

> The test workflow cannot be used with the failover deployment until it is activated.

> The failover deployments must use the same platform and ArcGIS Enterprise version as the active one, while other properties, such as operating system and EC2 instance types could differ from the active deployment.

> Don't backup failover deployment until it is activated.

## In-Place Updates and Upgrades

GitHub Actions workflow enterprise-base-linux-aws-application supports upgrade mode used to in-place patch or upgrade the base ArcGIS Enterprise applications on the EC2 instances. In the upgrade mode, the workflow copies the required patches and setups to the private repository S3 bucket and downloads them to the EC2 instances. If the ArcGIS Enterprise version was changed, it installs the new version of the ArcGIS Enterprise applications and re-configures the applications.

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the EC2 instances.
2. Add Portal for ArcGIS and ArcGIS Server authorization files for the new ArcGIS Enterprise version to `config/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run enterprise-base-linux-aws-application workflow using the branch.

> Back up the deployment and test the upgrade process on a test/failover deployment before upgrading the active deployment.

## Destroying Deployments

GitHub Actions workflow **enterprise-base-linux-aws-destroy** destroys AWS resources created by enterprise-base-linux-aws-infrastructure and enterprise-base-linux-aws-application workflows.

The workflow uses [infrastructure](infrastructure/README.md) and [application](application/README.md) Terraform templates with [infrastructure.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/infrastructure.tfvars.json) and [application.tfvars.json](../../config/aws/arcgis-enterprise-base-linux/application.tfvars.json) config files.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseDestroy

Instructions:

1. Run enterprise-base-linux-aws-destroy workflow using the branch.

> enterprise-base-linux-aws-destroy workflow does not delete the deployment's backups.