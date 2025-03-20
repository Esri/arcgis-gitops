# Templates for ArcGIS Enterprise on AWS

The templates provide GitHub Actions workflows for ArcGIS Enterprise operations on [Amazon Web Services (AWS)](https://aws.amazon.com/) for Windows, Linux, and Kubernetes platforms.

The workflows require:

* GitHub.com user account or GitHub Enterprise Server with enabled GitHub Actions
* Amazon Web Services (AWS) account
* (For Windows and Linux platforms) ArcGIS Online user account to download ArcGIS Enterprise installation media from [MyEsri](https://my.esri.com)
* (For Kubernetes platform) Docker Hub account that has access to private repositories with ArcGIS Enterprise on Kubernetes container images
* Authorization files for ArcGIS Enterprise software
* SSL certificates for the ArcGIS Enterprise site domain names

On Windows and Linux platforms the workflows use:

* [AWS CLI](https://aws.amazon.com/cli/) to manage AWS resources
* [Packer by HashiCorp](https://developer.hashicorp.com/packer) to build ArcGIS Enterprise EC2 AMIs
* [Terraform CLI by HashiCorp](https://developer.hashicorp.com/terraform/cli) to provision infrastructure in AWS
* [AWS Systems Manager (SSM)](https://aws.amazon.com/systems-manager/) to remotely manage system and application configuration of the EC2 instances
* [Python scripts](./scripts/README.md) to invoke AWS services and download installation media
* [Cinc Client](https://cinc.sh/) and [Chef Cookbooks for ArcGIS](https://esri.github.io/arcgis-cookbook/) to install and configure ArcGIS Enterprise applications, or
* [Ansible](https://www.ansible.com/) and [Ansible Collections for ArcGIS](../ansible_collections/README.md) to install and configure ArcGIS Enterprise applications
* [Enterprise Admin CLI](../enterprise-admin-cli/README.md) container image to test the deployment
  
On Kubernetes platform the workflows use:

* [AWS CLI](https://aws.amazon.com/cli/) to manage AWS resources
* [Terraform CLI by HashiCorp](https://developer.hashicorp.com/terraform/cli) to provision infrastructure in AWS
* [Helm Charts for ArcGIS Enterprise on Kubernetes](https://links.esri.com/enterprisekuberneteshelmcharts/1.2.0/deploy-guide) to install and configure ArcGIS Enterprise organization
* [Enterprise Admin CLI](../enterprise-admin-cli/README.md) container image to invoke ArcGIS Enterprise Admin services and test the deployment

Basic knowledge of Git and AWS is required to use the templates. Knowledge of the other technologies is recommended to modify or extend the templates.  

## Templates

An *ArcGIS Enterprise site* in this context is a group of *deployments* that typically include a [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm) or [ArcGIS Enterprise on Kubernetes deployment](https://enterprise-k8s.arcgis.com/en/latest/deploy/system-architecture.htm) plus [additional server deployments](https://enterprise.arcgis.com/en/get-started/latest/windows/additional-server-deployment.htm) in different roles.

The following templates are available for AWS:

* [arcgis-site-core](arcgis-site-core/README.md) - Provision core AWS resources for ArcGIS Enterprise site
* [arcgis-enterprise-base-windows](arcgis-enterprise-base-windows/README.md) - Base ArcGIS Enterprise on Windows deployment operations
* [arcgis-enterprise-base-linux](arcgis-enterprise-base-linux/README.md) - Base ArcGIS Enterprise on Linux deployment operations
* [arcgis-enterprise-k8s](arcgis-enterprise-k8s/README.md) - ArcGIS Enterprise on Kubernetes deployment operations
* [arcgis-server-linux](arcgis-server-linux/README.md) - ArcGIS Server on Linux deployment operations

## Triggering Workflows

By default, the workflows are configured with "workflow_dispatch" event that enables workflows to be triggered manually. To trigger a workflow manually, navigate to the repository on GitHub, click on the "Actions" tab, select the workflow to run, select the branch, and click the "Run workflow" button.

> Note that the deployments may belong to different *environments* such as "production" and "staging". Each environment may have its own branch in the repository. It's recommended to use protected `main` branch for the production environment and create separate branches for other environments.

The list of workflows in GitHub Actions page shows only the workflows present in /.github/workflows directory of the "main" branch, but the workflow runs use the workflow files from the selected branch. To enable workflows, copy the workflows' .yaml files from the template's `workflows` directory to `/.github/workflows` directory in both the `main` branch and the environment branch, commit the changes, and push the branches to GitHub.

The workflows can be modified to use other triggering events such as push, pull_request, or schedule. Consider using "schedule" event to schedule backups and "pull_request" event to check the infrastructure changes by "terraform plan" command. Note that scheduled workflows run on the latest commit on the `main` (or default) branch.

## Configuration Files

The workflows use configuration files to define the parameters of the deployments. The configuration files are in JSON format and are stored in the `/config/aws` directory of the repository. The configuration files must be in the same branch as the workflows that use them.

The configuration files may reference other files such as software authorization files and SSL certificates. The workflows symlink `~/config/` paths to the `config` directory path in the GitHub Actions runner workspace. Keep the referenced files in subdirectories of the `/config` directory and reference them as `~/config/<dir>/<file>`.

## IAM Policies

AWS permissions required by the workflows are defined in [IAM policies](iam-policies/README.md) JSON files. Modify the JSON files if needed and use them to create IAM policies.

## Terraform Child Modules

A Terraform module can call other modules to include their resources into the configuration. A module that has been called by another module is often referred to as a *child module*. The templates use a collection of [child modules](./modules/README.md) that can be called multiple times within the same configuration, and multiple configurations can use the same child module.

## Instructions

The specific guidance for using the templates depends on the use case and may involve various customizations. The following steps just demonstrate the typical use case.

### 1. Create GitHub Repository

[Create a new private GitHub repository](https://github.com/new?template_name=arcgis-gitops&template_owner=Esri&description=ArcGIS%20Enterprise%20on%20AWS&name=arcgis-enterprise) from https://github.com/esri/arcgis-gitops template repository.

Use separate GitHub repositories for each ArcGIS Enterprise site and separate Git branches for different environments.

> When operating multiple similar ArcGIS Enterprise sites, consider first forking and modifying https://github.com/esri/arcgis-gitops template repository and then creating repositories for the sites from the modified template.

### 2. Create Required AWS Resources

Create IAM user that will be used by the workflows and add the required policies to the user.

> The templates use the same AWS credentials for all the workflows. To implement the principle of least privilege and enforce separation of duties with appropriate authorization for each interaction with AWS resources, consider modifying the workflows to use different AWS credentials for different workflows. Consider using separate IAM users for core infrastructure, deployments infrastructure, and application workflows.  

Create a private S3 bucket for the [Terraform backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3). Make sure that the IAM user has the [S3 bucket permissions](https://developer.hashicorp.com/terraform/language/settings/backends/s3#s3-bucket-permissions) required by Terraform.

> It is recommended that to enable bucket versioning on the S3 bucket to allow for state recovery in the case of accidental deletions and human error.

### 3. GitHub Repository Settings

Configure secrets and variables for GitHub Actions in the repository settings.

#### Secrets

| Name                   | Description                 |
|------------------------|-----------------------------|
| AWS_ACCESS_KEY_ID      | AWS access key Id           |
| AWS_SECRET_ACCESS_KEY  | AWS secret access key       |

For ArcGIS Enterprise on Windows and Linux:

| Name                   | Description                 |
|------------------------|-----------------------------|
| ARCGIS_ONLINE_USERNAME | ArcGIS Online user name     |
| ARCGIS_ONLINE_PASSWORD | ArcGIS Online user password |

For ArcGIS Enterprise on Kubernetes:

| Name                        | Description              |
|-----------------------------|--------------------------|
| CONTAINER_REGISTRY_USER     | Docker Hub user name     |
| CONTAINER_REGISTRY_PASSWORD | Docker Hub user password |

#### Variables

| Name                        | Description                         |
|-----------------------------|-------------------------------------|
| AWS_DEFAULT_REGION          | Default AWS region Id               |
| TERRAFORM_BACKEND_S3_BUCKET | Terraform backend S3 bucket         |

Run validate-settings-aws GitHub Actions workflow to validate the settings.

> If the GitHub subscription plan supports GitHub Actions Environments, consider [environment secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) to use secrets specific to each environment.

### 4. Create the Primary Site

Provision core AWS resources for the ArcGIS Enterprise site using the [arcgis-site-core](arcgis-site-core/README.md) template.

Create base ArcGIS Enterprise deployment using the [arcgis-enterprise-base-windows](arcgis-enterprise-base-windows/README.md) or [arcgis-enterprise-base-linux](arcgis-enterprise-base-linux/README.md) templates.

Optionally, create deployments for each require additional server roles.

> Consult the README files of the templates to create and operate the required ArcGIS Enterprise deployments.

### 5. Create the Failover Site

One common approach to responding to a disaster scenario is to switch traffic to a failover site, which exists to take on traffic when a primary site identifies or experiences issues.

To create a failover site for Windows and Linux platforms:

1. Create a new Git branch from the branch of the active site.
2. Change "site_id" property in all the configuration files of the site's deployments to a new unique Id of the failover site.
   > The "site_id" value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-).
3. Change the "backup_site_id" property in the restore.tfvars.json configuration files of the failover branch to the active "site_id".
4. Commit the changes to the Git branch and push the branch to GitHub.
5. Deploy the failover site using the failover branch.
6. Backup all the deployments of the active site.
7. Restore all the deployments of the failover site.

> Sites configured to receive traffic from clients are referred to as *primary*, *active*, or *live*.

To activate the failover site:

1. Retrieve DNS name of the load balancer created by the infrastructure workflow, and
2. Update the CNAME record for the base ArcGIS Enterprise domain name in the DNS server.

> The test workflow cannot be used with the failover site deployments until it is activated.

> The failover site deployments must use the same platform and ArcGIS Enterprise version as the active one, while other properties, such as operating system and EC2 instance types could differ from the active deployment.
