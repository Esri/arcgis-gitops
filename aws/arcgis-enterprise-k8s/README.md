# ArcGIS Enterprise on Kubernetes Deployment in Amazon EKS

The template provides GitHub Actions workflows for [ArcGIS Enterprise on Kubernetes](https://www.esri.com/en-us/arcgis/products/arcgis-enterprise/kubernetes) deployment and operations in Amazon EKS cluster.

Supported ArcGIS Enterprise on Kubernetes versions:

* 11.1.0
* 11.2.0

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Provision core AWS resources for ArcGIS Enterprise site and deploy EKS cluster using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch and the deployment branch, commit the changes, and push the branches to GitHub.

> Refer to READMEs of the Terraform modules for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of ArcGIS Enterprise on Kubernetes includes provisioning container images, creating ingress controller, creating ArcGIS Enterprise organization, and testing the deployment web services.

> The IAM principal used by the template's workflows must have the EKS cluster administrator permissions. The IAM principal used to create the EKS cluster is granted the required permissions by site-k8s-cluster-aws workflow.

### 1. Provisioning Container Images

GitHub Actions workflow **enterprise-k8s-aws-image** builds container image for [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) and pushes it to private AWS Elastic Container Registry (ECR) repository. If "pull_through_cache" property is set to `false`, the workflow also copies container images of the ArcGIS Enterprise on Kubernetes version from DockerHub to the private ECR repositories.

The workflow uses [shell scripts](image/README.md) with [image.vars.json](../../config/aws/arcgis-enterprise-k8s/image.vars.json) config file.

Required IAM policies:

* ArcGISEnterpriseK8s

Instructions:

1. Change "arcgis_version" property in the config file to the required ArcGIS Enterprise on Kubernetes version.
2. Commit the changes to the Git branch and push the branch to GitHub.
3. Run enterprise-k8s-aws-image workflow using the branch.

> Copying the container images may take several hours.

### 2. Create Ingress Controller

GitHub Actions workflow **enterprise-k8s-aws-ingress** creates a Kubernetes namespace for ArcGIS Enterprise on
Kubernetes deployment in Amazon EKS cluster and a cluster-level ingress controller that routes traffic to the deployment.

> The "deployment_id" determines the Kubernetes namespace for the deployment. The "deployment_id" must be unique within the EKS cluster.

The workflow uses [ingress](ingress/README.md) Terraform module with [ingress.tfvars.json](../../config/aws/arcgis-enterprise-k8s/ingress.tfvars.json) config file.

Required IAM policies:

* ArcGISEnterpriseK8s
* TerraformBackend

Workflow Outputs:

* alb_dns_name - DNS name of the load balancer

Instructions:

1. Provision or import SSL certificate for the ArcGIS Enterprise domain name into AWS Certificate Manager service in the selected AWS region and set "ssl_certificate_arn" property in the config file to the certificate ARN.
2. Set "deployment_fqdn" property to the ArcGIS Enterprise deployment domain name.
3. If Route53 DNS is used, set "hosted_zone_id" property to the Route 53 hosted zone ID of the ArcGIS Enterprise domain name.
4. Commit the changes to a Git branch and push the branch to GitHub.
5. Run enterprise-k8s-aws-ingress workflow using the branch.
6. If "hosted_zone_id" property was not specified, retrieve DNS name of the load balancer created by the workflow and create a CNAME record for it within the DNS server of the ArcGIS Enterprise domain name.

> Job outputs are not shown in the properties of completed GitHub Actions run. To retrieve the outputs, check the run logs of "Run Terraform" step.

> See [Elastic Load Balancing SSL negotiation configuration](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies) for the list of SSL policies.

### 3. Create ArcGIS Enterprise Organization

GitHub Actions workflow **enterprise-k8s-aws-organization** deploys ArcGIS Enterprise on Kubernetes in Amazon EKS cluster and creates an ArcGIS Enterprise organization.

The workflow uses [organization](organization/README.md) Terraform template with [organization.tfvars.json](../../config/aws/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseK8s

Outputs:

* arcgis_enterprise_manager_url - ArcGIS Enterprise Manager URL
* arcgis_enterprise_portal_url - ArcGIS Enterprise Portal URL

Instructions:

1. Set "helm_charts_version" property to the Helm Charts for ArcGIS Enterprise on Kubernetes version for the ArcGIS Enterprise on Kubernetes version.
2. Add ArcGIS Enterprise on Kubernetes authorization file for the ArcGIS Enterprise version to `/config/authorization/<ArcGIS version>` directory of the repository and set "authorization_file_path" property to the file paths.
3. Set "system_arch_profile" property to the required ArcGIS Enterprise on Kubernetes architecture profile.
4. Set "deployment_fqdn" property to the ArcGIS Enterprise deployment fully qualified domain name.
5. Set "admin_username", "admin_password", "admin_first_name", "admin_last_name", "admin_email", "security_question", and "security_question_answer" to the initial ArcGIS Enterprise administrator account properties.
6. (Optional) Update "storage" property to configure the required storage classes, sizes, and types of the ArcGIS Enterprise deployment data stores.
7. Commit the changes to the Git branch and push the branch to GitHub.
8. Run enterprise-k8s-aws-organization workflow using the branch.

> '~/config/' paths is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test ArcGIS Enterprise Deployment

GitHub Actions workflow **enterprise-k8s-aws-test** tests the ArcGIS Enterprise deployment.

The workflow executes "test-publish-csv" script from [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) to test the deployment's health. The scrip runs in "enterprise-admin-cli" Kubernetes pod that impersonates an ArcGIS Enterprise user by retrieving the user credentials from "admin-cli-credentials" Kubernetes secret.

Required IAM policies:

* ArcGISEnterpriseK8s

Instructions:

1. Run enterprise-k8s-aws-test workflow using the branch.

## Backups and Disaster Recovery

The templates support configuring the organization's disaster recovery settings, default backup store in S3 bucket, and provides workflows for [backup and restore](https://enterprise-k8s.arcgis.com/en/latest/administer/backup-and-restore.htm) operations.

### Create Backups

GitHub Actions workflow **enterprise-k8s-aws-backup** creates [ArcGIS Enterprise on Kubernetes backups](https://enterprise-k8s.arcgis.com/en/latest/administer/create-a-backup.htm).

The workflow executes "create-backup" command from [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) in "enterprise-admin-cli" Kubernetes pod that impersonates an ArcGIS Enterprise user by retrieving the user credentials from "admin-cli-credentials" Kubernetes secret.

The command parameters are retrieved from [backup.vars.json](../../config/aws/arcgis-enterprise-k8s/backup.vars.json) config file.

Required IAM policies:

* ArcGISEnterpriseK8s

Instructions:

1. Set "passcode" property in the config file to the pass code that will be used to encrypt content of the backup.
2. Set "retention" property in the config file to backup retention interval (in days).
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-k8s-aws-backup workflow using the branch.

> To meet the required recovery point objective (RPO), schedule runs of enterprise-k8s-aws-backup workflow by configuring 'schedule' event in enterprise-k8s-aws-backup.yaml file.

### Restore from Backups

GitHub Actions workflow **enterprise-k8s-aws-restore** [restores the organization](https://enterprise-k8s.arcgis.com/en/latest/administer/restore-a-backup.htm) to the state it was in when a specific backup was created. When restoring an organization to a previous state, any existing content and data present in its current state is replaced with the data contained in the backup.

The workflow executes "restore-organization" command from [Enterprise Admin CLI](../../enterprise-admin-cli/README.md) in "enterprise-admin-cli" Kubernetes pod that impersonates an ArcGIS Enterprise user by retrieving the user credentials from "admin-cli-credentials" Kubernetes secret.

The command parameters are retrieved from [restore.vars.json](../../config/aws/arcgis-enterprise-k8s/restore.vars.json) config file.

Required IAM policies:

* ArcGISEnterpriseK8s

Instructions:

1. Set "backup" property in the config file to the backup name. If "backup" property is set to null or empty string, the latest completed backup in the store will be used.
2. Set "passcode" property in the config file to the pass code used to create the backup.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-k8s-aws-restore workflow using the branch.

## Updates and Upgrades

GitHub Actions workflow enterprise-k8s-aws-organization supports [updates and upgrades of ArcGIS Enterprise on Kubernetes](https://enterprise-k8s.arcgis.com/en/latest/administer/understand-updates.htm) organizations.

Instructions:

1. If pull through cache is not configured, copy the container images of the new ArcGIS Enterprise version to Amazon ECR.
2. In case of upgrade to a new version, add ArcGIS Enterprise on Kubernetes authorization files for the new ArcGIS Enterprise version to `/config/authorization/<ArcGIS version>` directory of the repository and set "authorization_file_path" property in [organization.tfvars.json](../../config/aws/arcgis-enterprise-k8s/organization.tfvars.json) config file to the file paths.
3. Set "helm_charts_version" property to the Helm Charts version of the new ArcGIS Enterprise on Kubernetes version (see "Chart Version Compatibility" section in the charts' READMEs).
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Run enterprise-k8s-aws-organization workflow using the branch.

> Make a backup of the organization before performing an update or upgrade.

## Destroying Deployments

GitHub Actions workflow **enterprise-k8s-aws-destroy** destroys AWS resources created by enterprise-k8s-aws-organization and (optionally) enterprise-k8s-aws-ingress workflows.

The workflow uses [organization](organization/README.md) Terraform template with [organization.tfvars.json](../../config/aws/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseK8s

Inputs:

* delete_namespace - (Optional) Set to "true" to delete the Kubernetes namespace.

Instructions:

1. Run enterprise-k8s-aws-destroy workflow using the branch.

## Disconnected Environments

When deploying ArcGIS Enterprise on Kubernetes in disconnected environments:

1. Make sure that the EKS cluster nodes are running in "isolated" subnets.
2. When creating ingress with arcgis-enterprise-k8s-ingress workflow, set "internal_load_balancer" property to `true` in ingress.tfvars.json config file.
3. Use private Route53 VPC hosted zone for the deployment DNS as public DNS servers are not available.

> The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.
