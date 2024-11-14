# ArcGIS Enterprise on Kubernetes Deployment in AKS

The template provides GitHub Actions workflows for [ArcGIS Enterprise on Kubernetes](https://www.esri.com/en-us/arcgis/products/arcgis-enterprise/kubernetes) deployment and operations in Microsoft Azure Kubernetes Services (AKS) cluster.

Supported ArcGIS Enterprise on Kubernetes versions:

* 11.3.0

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Provision core Azure resources for ArcGIS Enterprise site and deploy AKS cluster using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch and the deployment branch, commit the changes, and push the branches to GitHub.

> Refer to READMEs of the Terraform modules for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of ArcGIS Enterprise on Kubernetes includes provisioning container images, creating ingress resources, creating ArcGIS Enterprise organization, and testing the deployment web services.

> The service principal used by the template's workflows must have the cluster administrator permissions.

### 1. Provisioning Container Images

GitHub Actions workflow **enterprise-k8s-azure-image** builds container image for [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) and pushes it to the private  container registry (ACR) repository.

The workflow uses [shell scripts](image/README.md) with [image.vars.json](../../config/azure/arcgis-enterprise-k8s/image.vars.json) config file.

Required user roles:

* AcrPush

Instructions:

1. Commit the changes to the Git branch and push the branch to GitHub.
2. Run enterprise-k8s-azure-image workflow using the branch.

### 2. Create Ingress Resources

GitHub Actions workflow **enterprise-k8s-azure-ingress** creates a Kubernetes namespace for ArcGIS Enterprise on Kubernetes deployment in the AKS cluster and ingress resources that routes traffic to the deployment.

The workflow uses [ingress](ingress/README.md) Terraform module with [ingress.tfvars.json](../../config/azure/arcgis-enterprise-k8s/ingress.tfvars.json) config file.

> The "deployment_id" config property value is used as the Kubernetes namespace for the deployment. The "deployment_id" value must be unique within the AKS cluster.

Required user roles:

* AppGw for Containers Configuration Manager
* Azure Kubernetes Service Cluster Admin Role

Workflow Outputs:

* alb_dns_name - DNS name of the load balancer

Instructions:

1. Add TLS certificate for the deployment's frontend HTTPS listener and the certificate's private key files in PEM format to `/config/certificates/` directory of the repository and set "tls_certificate_path" and "tls_private_key_path" config properties to the files' paths.
2. Add CA certificate file for backend TLS certificate validation in PEM format to `/config/certificates/` directory of the repository and set "ca_certificate_path" config property to the file's path.
3. Set "deployment_fqdn" property to the ArcGIS Enterprise deployment domain name.
4. If Azure DNS is used, set "hosted_zone_name" and "hosted_zone_resource_group" properties to the hosted zone name and resource group name of the ArcGIS Enterprise domain name DNS.
5. Commit the changes to a Git branch and push the branch to GitHub.
6. Run enterprise-k8s-azure-ingress workflow using the branch.
7. If Azure DNS is not used, retrieve DNS name of the load balancer created by the workflow and create a CNAME record for it within the DNS server of the ArcGIS Enterprise domain name.

> Job outputs are not shown in the properties of completed GitHub Actions run. To retrieve the outputs, check the run logs of "Run Terraform" step.

### 3. Create ArcGIS Enterprise Organization

GitHub Actions workflow **enterprise-k8s-azure-organization** deploys ArcGIS Enterprise on Kubernetes in AKS cluster and creates an ArcGIS Enterprise organization.

The workflow uses [organization](organization/README.md) Terraform template with [organization.tfvars.json](../../config/azure/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required user roles:

* Storage Account Contributor
* Storage Blob Data Owner
* Azure Kubernetes Service Cluster Admin Role

Outputs:

* arcgis_enterprise_manager_url - ArcGIS Enterprise Manager URL
* arcgis_enterprise_portal_url - ArcGIS Enterprise Portal URL

Instructions:

1. Set "helm_charts_version" property to the Helm Charts for ArcGIS Enterprise on Kubernetes version for the ArcGIS Enterprise on Kubernetes version.
2. Download the ArcGIS Enterprise on Kubernetes Helm Charts package archive for the charts version from [My Esri](https://www.esri.com/en-us/my-esri-login) and extract the archive to `azure/arcgis-enterprise-k8s/organization/helm-charts/arcgis-enterprise/<Helm Charts version>` folder in the repository.
3. Add ArcGIS Enterprise on Kubernetes authorization file for the ArcGIS Enterprise version to `/config/authorization/<ArcGIS version>` directory of the repository and set "authorization_file_path" property to the file paths.
4. Set "system_arch_profile" property to the required ArcGIS Enterprise on Kubernetes architecture profile.
5. Set "deployment_fqdn" property to the ArcGIS Enterprise deployment fully qualified domain name.
6. Set "admin_username", "admin_password", "admin_first_name", "admin_last_name", "admin_email", "security_question", and "security_question_answer" to the initial ArcGIS Enterprise administrator account properties.
7. (Optional) Update "storage" property to configure the required storage classes, sizes, and types of the ArcGIS Enterprise deployment data stores.
8. Commit the changes to the Git branch and push the branch to GitHub.
9. Run enterprise-k8s-azure-organization workflow using the branch.

> '~/config/' paths is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test ArcGIS Enterprise Deployment

GitHub Actions workflow **enterprise-k8s-azure-test** tests the ArcGIS Enterprise deployment.

The workflow executes "test-publish-csv" script from [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) to test the deployment's health. The scrip runs in "enterprise-admin-cli" Kubernetes pod that impersonates an ArcGIS Enterprise user by retrieving the user credentials from "admin-cli-credentials" Kubernetes secret.

Required user roles:

* Azure Kubernetes Service Cluster User Role

Instructions:

1. Run enterprise-k8s-azure-test workflow using the branch.

## Backups and Disaster Recovery

The templates support configuring the organization's disaster recovery settings, default backup store in S3 bucket, and provides workflows for [backup and restore](https://enterprise-k8s.arcgis.com/en/latest/administer/backup-and-restore.htm) operations.

### Create Backups

GitHub Actions workflow **enterprise-k8s-azure-backup** creates [ArcGIS Enterprise on Kubernetes backups](https://enterprise-k8s.arcgis.com/en/latest/administer/create-a-backup.htm).

The workflow executes "create-backup" command from [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) in "enterprise-admin-cli" Kubernetes pod that impersonates an ArcGIS Enterprise user by retrieving the user credentials from "admin-cli-credentials" Kubernetes secret.

The command parameters are retrieved from [backup.vars.json](../../config/azure/arcgis-enterprise-k8s/backup.vars.json) config file.

Required user roles:

* Azure Kubernetes Service Cluster User Role

Instructions:

1. Set "passcode" property in the config file to the pass code that will be used to encrypt content of the backup.
2. (Optional) Set "retention" property in the config file to backup retention interval (in days).
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-k8s-azure-backup workflow using the branch.

> To meet the required recovery point objective (RPO), schedule runs of enterprise-k8s-azure-backup workflow by configuring 'schedule' event in enterprise-k8s-azure-backup.yaml file.

### Restore from Backups

GitHub Actions workflow **enterprise-k8s-azure-restore** [restores the organization](https://enterprise-k8s.arcgis.com/en/latest/administer/restore-a-backup.htm) to the state it was in when a specific backup was created. When restoring an organization to a previous state, any existing content and data present in its current state is replaced with the data contained in the backup.

The workflow executes "restore-organization" command from [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) in "enterprise-admin-cli" Kubernetes pod that impersonates an ArcGIS Enterprise user by retrieving the user credentials from "admin-cli-credentials" Kubernetes secret.

The command parameters are retrieved from [restore.vars.json](../../config/azure/arcgis-enterprise-k8s/restore.vars.json) config file.

Required user roles:

* Azure Kubernetes Service Cluster User Role

Instructions:

1. (Optional) Set "backup" property in the config file to the backup name. If "backup" property is set to null or empty string, the latest completed backup in the store will be used.
2. Set "passcode" property in the config file to the pass code used to create the backup.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-k8s-azure-restore workflow using the branch.

## Updates and Upgrades

GitHub Actions workflow enterprise-k8s-azure-organization supports [updates and upgrades of ArcGIS Enterprise on Kubernetes](https://enterprise-k8s.arcgis.com/en/latest/administer/understand-updates.htm) organizations.

Instructions:

1. In case of upgrade to a new version, add ArcGIS Enterprise on Kubernetes authorization files for the new ArcGIS Enterprise version to `/config/authorization/<ArcGIS version>` directory of the repository and set "authorization_file_path" property in [organization.tfvars.json](../../config/azure/arcgis-enterprise-k8s/organization.tfvars.json) config file to the file paths.
2. Set "helm_charts_version" property to the Helm Charts version of the new ArcGIS Enterprise on Kubernetes version (see "Chart Version Compatibility" section in the charts' READMEs).
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-k8s-azure-organization workflow using the branch.

> Make a backup of the organization before performing an update or upgrade.

## Destroying Deployments

GitHub Actions workflow **enterprise-k8s-azure-destroy** destroys Azure resources created by enterprise-k8s-azure-organization and (optionally) enterprise-k8s-azure-ingress workflows.

The workflow uses [organization](organization/README.md) Terraform template with [organization.tfvars.json](../../config/azure/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required user roles:

* Storage Account Contributor
* Storage Blob Data Owner
* Azure Kubernetes Service Cluster Admin Role

Inputs:

* delete_namespace - (Optional) Set to "true" to delete the Kubernetes namespace.

Instructions:

1. Run enterprise-k8s-azure-destroy workflow using the branch.

## Disconnected Environments

When deploying ArcGIS Enterprise on Kubernetes in disconnected environments:

1. Make sure that the AKS cluster nodes are running in "internal" subnets.
2. Use private DNS hosted zone for the deployment DNS.

> The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.
