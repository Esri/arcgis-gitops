# ArcGIS Enterprise on Kubernetes Deployment in Amazon EKS

The template provides GitHub Actions workflows for [ArcGIS Enterprise on Kubernetes](https://www.esri.com/en-us/arcgis/products/arcgis-enterprise/kubernetes) deployment and operations in Amazon EKS cluster.

Supported ArcGIS Enterprise on Kubernetes versions:

* 11.1.0
* 11.2.0

Before running the template workflows:

1. Configure the GitHub repository settings as described in the [Instructions](../README.md#instructions) section.
2. Provision core AWS resources for ArcGIS Enterprise site and deploy EKS cluster using [arcgis-site-core](../arcgis-site-core/README.md) template.

To enable the template's workflows, copy the .yml files from the template's `workflows` directory to `/.github/workflows` directory in `main` branch and the deployment branch, commit the changes, and push the branches to GitHub.

> Refer to READMEs of the Terraform modules for descriptions of the configuration properties.

## Initial Deployment

Initial deployment of ArcGIS Enterprise on Kubernete includes: creating ingress controller, copying container images to Amazon ECR,  creating ArcGIS Enterprise organization, and testing the deployment web services.

### 1. Create Ingress Controller

GitHub Actions workflow **enterprise-k8s-aws-ingress** creates a Kubernetes namespace for ArcGIS Enterprise on
Kubernetes deployment in Amazon EKS cluster and a cluster-level ingress controller that routes traffic to the deployment.

The workflow uses [ingress](ingress/README.md) Terraform module with [ingress.tfvars.json](../../config/aws/arcgis-enterprise-k8s/ingress.tfvars.json) config file.

Required IAM policies:

* ArcGISEnterpriseK8s
* TerraformBackend

Workflow Outputs:

* alb_dns_name - DNS name of the load balancer

Instructions:

1. Provision or import SSL certificate for the ArcGIS Enterprise domain name into AWS Certificate Manager service in the selected AWS region and set "ssl_certificate_arn" property in the config file to the certificate ARN.
2. Set "arcgis_enterprise_fqdn" property to the ArcGIS Enterprise deployment domain name.
3. Commit the changes to a Git branch and push the branch to GitHub.
4. Run enterprise-k8s-aws-ingress workflow using the branch.
5. Retrieve the DNS name of the load balancer created by the workflow and create a CNAME record for it within the DNS server of the ArcGIS Enterprise domain name.

> The value of "deployment_id" property defines the deployment's Kubernetes namespace.

> See [Elastic Load Balancing SSL negotiation configuration](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies) for the list of SSL policies.

### 2. Copy Container Images to Amazon ECR

GitHub Actions workflow **enterprise-k8s-aws-image** copies the ArcGIS Enterprise on Kubernetes container images from DockerHub to AWS Elastic Container Registry (ECR) repositories.

The workflow uses [image-copy-ecr](image/README.md) script with [organization.tfvars.json](../../config/aws/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required IAM policies:

* ArcGISEnterpriseK8s

Instructions:

1. Change "arcgis_version" property in the config file to the required ArcGIS Enterprise on Kubernetes version.
2. Commit the changes to the Git branch and push the branch to GitHub.
3. Run enterprise-k8s-aws-image workflow using the branch.

> Copying of container images may take several hours.

### 3. Create ArcGIS Enterprise organization

GitHub Actions workflow **enterprise-k8s-aws-organization** deploys ArcGIS Enterprise on Kubernetes in Amazon EKS cluster and creates an ArcGIS Enterprise organization.

The workflow uses [organization](organization/README.md) Terraform template with [organization.tfvars.json](../../config/aws/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseK8s

Outputs:

* arcgis_enterprise_manager_url - ArcGIS Enterprise Manager URL
* arcgis_enterprise_portal_url - ArcGIS Enterprise Portal URL

Instructions:

1. Set "helm_charts_version" property to the Helm Charts for ArcGIS Enterprise on Kubernetes version that is compatible with the ArcGIS Enterprise on Kubernetes version.
2. Add ArcGIS Enterprise on Kubernetes authorization file for the ArcGIS Enterprise version to `/config/aws/authorization/<ArcGIS version>` directory of the repository and set "authorization_file_path" property to the file paths.
3. Set "system_arch_profile" property to the required ArcGIS Enterprise on Kubernetes architecture profile.
4. Set "arcgis_enterprise_fqdn" property to the ArcGIS Enterprise deployment fully qualified domain name.
5. Set "admin_username", "admin_password", "admin_first_name", "admin_last_name", "admin_email", "security_question", and "security_question_answer" to the initial ArcGIS Enterprise administrator account properties.
6. (Optional) Update "storage" property to configure the required storage classes, sizes, and types of the ArcGIS Enterprise deployment data stores.
7. Commit the changes to the Git branch and push the branch to GitHub.
8. Run enterprise-k8s-aws-organization workflow using the branch.

> '~/config/' paths is linked to the repository's /config directory. It's recommended to use /config directory for the configuration files.

### 4. Test ArcGIS Enterprise Deployment

GitHub Actions workflow **enterprise-k8s-aws-test** tests the ArcGIS Enterprise deployment.

The python [test script](../tests/arcgis-enterprise-base-test.py) uses [ArcGIS API for Python](https://developers.arcgis.com/python/) to publish a CSV file to the Portal for ArcGIS URL. The portal domain name and admin credentials are retrieved from organization.tfvars.json properties file.

Instructions:

1. Run enterprise-k8s-aws-test workflow using the branch.

## Backups and Disaster Recovery

TBD

### Create Backups

[TBD](https://enterprise-k8s.arcgis.com/en/latest/administer/create-a-backup.htm)

### Restore from Backups

[TBD](https://enterprise-k8s.arcgis.com/en/latest/administer/restore-a-backup.htm)

### Failover Deployment

[TBD](https://enterprise-k8s.arcgis.com/en/latest/administer/minimize-data-loss-and-downtime.htm)

## Updates and Upgrades

GitHub Actions workflow enterprise-k8s-aws-organization supports [updates and upgrades of ArcGIS Enterprise on Kubernetes](https://enterprise-k8s.arcgis.com/en/latest/administer/understand-updates.htm) organizations.

Instructions:

1. (For updates) Update manifest file of the current ArcGIS Enterprise on Kubernetes version in /config/aws/arcgis-enterprise-k8s/manifests directory to the one that includes container images required by the update.
2. (For upgrades) Change "arcgis_version" property in organization.tfvars.json file to the new ArcGIS Enterprise on Kubernetes version.
3. Commit the changes to the Git branch and push the branch to GitHub.
4. Run enterprise-k8s-aws-image workflow using the branch.
5. (For upgrades) Add ArcGIS Enterprise on Kubernetes authorization files for the new ArcGIS Enterprise version to `/config/aws/authorization/<ArcGIS version>` directory of the repository and set "authorization_file_path" property to the file paths.
6. Set "helm_charts_version" property to the Helm Charts version compatible with the new ArcGIS Enterprise on Kubernetes version (see "Chart Version Compatibility" section in the charts' READMEs).
7. Set "upgrade_token" property to a long lived (>= 6 hours expiration time) token generated for ArcGIS Enterprise organization administrator account through the `https://<arcgis_enterprise_fqdn>/<arcgis_enterprise_fqdn>/sharing/rest/generateToken` endpoint.
8. Commit the changes to the Git branch and push the branch to GitHub.
9. Run enterprise-k8s-aws-organization workflow using the branch.

> Make a backup of your organization before performing an update or upgrade.

## Destroying Deployments

GitHub Actions workflow **enterprise-k8s-aws-destroy** destroys AWS resources created by enterprise-k8s-aws-organization and (optionally) enterprise-k8s-aws-ingress workflows.

The workflow uses [organization](organization/README.md) Terraform template with [organization.tfvars.json](../../config/aws/arcgis-enterprise-k8s/organization.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISEnterpriseK8s

Inputs:

* delete_namespace - (Optional) Set to "true" to delete the kubernetes namespace.

Instructions:

1. Run enterprise-k8s-aws-destroy workflow using the branch.
