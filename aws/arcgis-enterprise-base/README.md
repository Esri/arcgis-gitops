# Base ArcGIS Enterprise Deployment on AWS

The template provides GitHub Actions workflows for [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm) operations on linux and windows platforms.

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Provision core AWS resources for ArcGIS Enterprise site using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch, commit the changes, and push the branch to GitHub.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of base ArcGIS Enterprise includes: building images, provisioning AWS resources, configuring the applications, and testing the deployment web services.

### 1. Build Images

GitHub Actions workflow **arcgis-enterprise-base-aws-image** creates EC2 AMIs for base ArcGIS Enterprise deployment.

The workflow uses:

* [linux/image](linux/image/README.md) Packer template with [linux/config/image.vars.json](linux/config/image.vars.json) config file on linux platform, and
* [windows/image](windows/image/README.md) Packer template with  [windows/config/image.vars.json](windows/config/image.vars.json) config file on windows platform.

Required IAM policies:

* ArcGISEnterpriseImage

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in image.vars.json file to the lists of patch file names that must be installed on the images.
2. (Windows only) Set "run_as_password" property in image.vars.json file to the password of `arcgis` user account.
3. Commit the changes to a Git branch and push the branch to GitHub.
4. Run arcgis-enterprise-base-aws-image workflow using the branch.

Example image.vars.json properties file for base ArcGIS Enterprise 11.2 on Linux RHEL 8:

```json
{
    "arcgis_data_store_patches": [
        "ArcGIS-112-DS-*-linux.tar"
    ],
    "arcgis_portal_patches": [
        "ArcGIS-112-PFA-*-linux.tar"
    ],
    "arcgis_server_patches": [
        "ArcGIS-112-S-*-linux.tar"
    ],
    "arcgis_version": "11.2",
    "arcgis_web_adaptor_patches": [],
    "deployment_id": "arcgis-enterprise-base",
    "instance_type": "m7i.xlarge",
    "os": "rhel8",
    "root_volume_size": 100,
    "run_as_user": "arcgis",
    "site_id": "arcgis-enterprise"
}
```

> In the configuration files, "os" and "arcgis_version" properties values for the same deployment must match across all the configuration files of the deployment.

### 2. Provision AWS Resources

GitHub Actions workflow **arcgis-enterprise-base-aws-infrastructure** creates AWS resources for base ArcGIS Enterprise deployment.

The workflow uses:

* [linux/infrastructure](linux/infrastructure/README.md) Terraform template with [linux/config/infrastructure.tfvars.json](linux/config/infrastructure.tfvars.json) config file on linux platform, and
* [windows/infrastructure](windows/infrastructure/README.md) Terraform template with [windows/config/infrastructure.tfvars.json](windows/config/infrastructure.tfvars.json) on windows platform.

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
5. Run arcgis-enterprise-base-aws-infrastructure workflow using the branch.
6. Retrieve the DNS name of the load balancer created by the workflow and create a CNAME record for it within the DNS server of the base ArcGIS Enterprise domain name.

Example infrastructure.tfvars.json properties file for base ArcGIS Enterprise on Linux RHEL 8:

```json
{
  "client_cidr_blocks": [
    "0.0.0.0/0"
  ],
  "deployment_id": "arcgis-enterprise-base",
  "instance_type": "m7i.xlarge",
  "key_name": "<my key>",
  "os": "rhel8",
  "root_volume_size": 100,
  "site_id": "arcgis-enterprise",
  "ssl_certificate_arn": "arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/XXXXXXXX",
  "subnet_type": "private"
}
```

> When updating the infrastructure, first run the workflow with terraform_command=plan before running it with terraform_command=apply and check the logs to make sure that Terraform does not destroy and recreate critical AWS resources such as EC2 instances.

### 3. Configure Applications

GitHub Actions workflow **arcgis-enterprise-base-aws-application** configures or upgrades base ArcGIS Enterprise on EC2 instances.

The workflow uses:

* [linux/application](linux/application/README.md) Terraform template with [linux/config/application.tfvars.json](linux/config/application.tfvars.json) config file on linux platform, and
* [windows/application](windows/application/README.md) Terraform template with [windows/config/application.tfvars.json](window/config/application.tfvars.json) config file on windows platform.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Inputs:

* terraform_command - Terraform command (apply|plan)

Outputs:

* arcgis_portal_url - Portal for ArcGIS URL

Instructions:

1. Add Portal for ArcGIS and ArcGIS Server authorization files for the ArcGIS Enterprise version to `aws/arcgis-enterprise-base/data/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths relative to `<platform>/application` directory.
2. Set "domain_name" property in application.tfvars.json file to the base ArcGIS Enterprise deployment domain name.
3. Set "admin_username", "admin_password", "admin_full_name", "admin_description", "admin_email", "security_question", and "security_question_answer" in application.tfvars.json file to the initial ArcGIS Enterprise administrator account properties.
4. (Optionally) Add SSL certificates for the base ArcGIS Enterprise domain name and trusted root certificates to `data/certificates` directory and set "keystore_file_path" and "root_cert_file_path" properties in application.tfvars.json file to the file paths relative to `<platform>/application` directory. Set "keystore_file_password" property to password of the keystore file.
5. (Windows only) Set "run_as_password" property in application.tfvars.json file to the password of `arcgis` user account.
6. Commit the changes to the Git branch and push the branch to GitHub.
7. Run arcgis-enterprise-base-aws-application workflow using the branch.

Example application.tfvars.json properties file for base ArcGIS Enterprise 11.2 on Linux RHEL 8:

```json
{
  "admin_description": "Initial account administrator",
  "admin_email": "siteadmin@domain.com",
  "admin_full_name": "Administrator",
  "admin_password": "<admin_password>",
  "admin_username": "siteadmin",
  "arcgis_data_store_patches": [],
  "arcgis_portal_patches": [],
  "arcgis_server_patches": [],
  "arcgis_version": "11.2",
  "arcgis_web_adaptor_patches": [],
  "deployment_id": "arcgis-enterprise-base",
  "domain_name": "domain.com",
  "is_upgrade": false,
  "keystore_file_password": "<keystore_file_password>",
  "keystore_file_path": "../../data/certificates/keystore.pfx",
  "log_level": "INFO",
  "os": "rhel8",
  "portal_authorization_file_path": "../../data/authorization/11.2/portal_112.json",
  "portal_user_license_type_id": "",
  "root_cert_file_path": "../../data/certificates/root.crt",
  "run_as_user": "arcgis",
  "security_question_answer": "<security_question_answer>",
  "security_question": "What city were you born in?",
  "server_authorization_file_path": "../../data/authorization/11.2/server_112.ecp",
  "site_id": "arcgis-enterprise"
}
```

### 4. Test Base ArcGIS Enterprise Deployment

GitHub Actions workflow **arcgis-enterprise-base-aws-test** tests base ArcGIS Enterprise deployment.

The python [test script](../tests/arcgis-enterprise-base-test.py) uses [ArcGIS API for Python](https://developers.arcgis.com/python/) to publish a CSV file to the Portal for ArcGIS URL. The portal domain name and admin credentials are retrieved from application.tfvars.json properties file.

Instructions:

1. Run arcgis-enterprise-base-aws-test workflow using the branch.

## Backups and Disaster Recovery

The templates support application-level base ArcGIS Enterprise backup and restore operations using [WebGISDR](https://enterprise.arcgis.com/en/portal/latest/administer/windows/create-web-gis-backup.htm) tool across multiple deployments.

### Create Backups

GitHub Actions workflow **arcgis-enterprise-base-aws-backup** creates base ArcGIS Enterprise backups using WebGISDR utility.

The workflow uses:

* [linux/backup](linux/backup/README.md) Terraform template with [linux/config/backup.tfvars.json](linux/config/backup.tfvars.json) config file on linux platform, and
* [windows/backup](windows/backup/README.md) Terraform template with [windows/config/backup.tfvars.json](windows/config/backup.tfvars.json) config file on windows platform.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Set "admin_username" and "admin_password" properties in backup.tfvars.json file to the portal administrator user name and password respectively.
2. (Windows only) Set "run_as_password" property in backup.tfvars.json file to the password of `arcgis` user account.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run arcgis-enterprise-base-aws-backup workflow using the branch.

> To meet the required recovery point objective (RPO), schedule runs of arcgis-enterprise-base-aws-backup workflow by configuring 'schedule' event in arcgis-enterprise-base-aws-backup.yml file.

> Base ArcGIS Enterprise deployments in a site use the same S3 bucket for backups. Run backups only for the active deployment branch.

Example backup.tfvars.json properties file for base ArcGIS Enterprise on Linux:

```json
{
  "admin_password": "<admin_password>",
  "admin_username": "siteadmin",
  "backup_restore_mode": "backup",
  "deployment_id": "arcgis-enterprise-base",
  "execution_timeout": 36000,
  "portal_admin_url": "https://localhost:7443/arcgis",
  "run_as_user": "arcgis",
  "site_id": "arcgis-enterprise"
}
```

### Restore from Backups

GitHub Actions workflow **arcgis-enterprise-base-aws-restore** restores base ArcGIS Enterprise from backup using WebGISDR utility.

The workflow uses:

* [linux/restore](linux/restore/README.md) Terraform template with [linux/config/restore.tfvars.json](linux/config/restore.tfvars.json) config file on linux platform, and
* [windows/restore](windows/restore/README.md) Terraform template with [windows/config/restore.tfvars.json](windows/config/restore.tfvars.json) on windows platform.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseApplication

Instructions:

1. Set "admin_username" and "admin_password" properties in restore.tfvars.json file to the portal administrator user name and password respectively.
2. (Windows only) Set "run_as_password" property in restore.tfvars.json file to the password of `arcgis` user account.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run arcgis-enterprise-base-aws-restore workflow using the branch.

Example restore.tfvars.json properties file for base ArcGIS Enterprise on Linux:

```json
{
  "admin_password": "<admin_password>",
  "admin_username": "siteadmin",
  "backup_restore_mode": "backup",
  "deployment_id": "arcgis-enterprise-base",
  "execution_timeout": 36000,
  "portal_admin_url": "https://localhost:7443/arcgis",
  "run_as_user": "arcgis",
  "site_id": "arcgis-enterprise"
}
```

### Failover Deployment

One common approach to responding to a disaster scenario is to switch traffic to a failover deployment, which exists to take on traffic when a primary deployment identifies or experiences issues.

To create failover deployment:

1. Create a new Git branch from the branch of the active deployment.
2. Change "deployment_id" property in all the configuration files (image.vars.json, infrastructure.tfvars.json, application.tfvars.json, backup.tfvars.json, restore.tfvars.json) to a new unique Id of the failover deployment.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run arcgis-enterprise-base-aws-backup workflow for the active deployment branch.
5. Run the following workflows for the failover deployment branch:
   1. arcgis-enterprise-base-aws-image
   2. arcgis-enterprise-base-aws-infrastructure
   3. arcgis-enterprise-base-aws-application
   4. arcgis-enterprise-base-aws-restore

To activate the failover deployment:

1. Retrieve DNS name of the load balancer created by the infrastructure workflow, and
2. Update the CNAME record for the base ArcGIS Enterprise domain name in the DNS server.

> The test workflow cannot be used with the failover deployment until it is activated.

> The failover deployments must use the same platform and ArcGIS Enterprise version as the active one, while other properties, such as operating system and EC2 instance types could differ from the active deployment.

> Don't backup failover deployment until it is activated.

## In-Place Updates and Upgrades

GitHub Actions workflow arcgis-enterprise-base-aws-application supports upgrade mode used to in-place patch or upgrade the base ArcGIS Enterprise applications on the EC2 instances. In the upgrade mode, the workflow copies the required patches and setups to the private repository S3 bucket and downloads them to the EC2 instances. If the ArcGIS Enterprise version was changed, it installs the new version of the ArcGIS Enterprise applications and re-configures the applications.

Instructions:

1. Set "arcgis_data_store_patches", "arcgis_portal_patches", "arcgis_server_patches", and "arcgis_web_adaptor_patches" properties in application.tfvars.json file to the lists of patch file names that must be installed on the EC2 instances.
2. Add Portal for ArcGIS and ArcGIS Server authorization files for the new ArcGIS Enterprise version to `data/authorization/<ArcGIS version>` directory of the repository and set "portal_authorization_file_path" and "server_authorization_file_path" properties in application.tfvars.json file to the file paths relative to `<platform>/application` directory.
3. Change "is_upgrade" property in application.tfvars.json file to `true`.
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run arcgis-enterprise-base-aws-application workflow using the branch.

> Back up the deployment and test the upgrade process on a test/failover deployment before upgrading the active deployment.

## Destroying Deployments

GitHub Actions workflow **arcgis-enterprise-base-aws-destroy** destroys AWS resources created by arcgis-enterprise-base-aws-infrastructure and arcgis-enterprise-base-aws-application workflows.

The workflow uses:

* [linux/infrastructure](linux/infrastructure/README.md) and [linux/application](linux/application/README.md) Terraform templates with [linux/config/infrastructure.tfvars.json](linux/config/infrastructure.tfvars.json) and [linux/config/application.tfvars.json](linux/config/application.tfvars.json) config files on linux platform, and
* [windows/infrastructure](windows/infrastructure/README.md) and [windows/application](windows/application/README.md) Terraform templates with [windows/config/infrastructure.tfvars.json](windows/config/infrastructure.tfvars.json) and [windows/config/application.tfvars.json](windows/config/application.tfvars.json) config files on windows platform.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseDestroy

Instructions:

1. Run arcgis-enterprise-base-aws-destroy workflow using the branch.

> arcgis-enterprise-base-aws-destroy workflow does not delete the deployment's backups.
