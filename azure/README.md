# Templates for ArcGIS Enterprise on Microsoft Azure

The templates provide GitHub Actions workflows for ArcGIS Enterprise operations on [Microsoft Azure](https://azure.microsoft.com/) for Windows, Linux, and Kubernetes platforms.

The workflows require:

* GitHub.com user account or GitHub Enterprise Server with enabled GitHub Actions
* Microsoft Azure account
* (For Windows and Linux platforms) ArcGIS Online user account to download ArcGIS Enterprise installation media from [MyEsri](https://my.esri.com)
* (For Kubernetes platform) Docker Hub account that has access to private repositories with ArcGIS Enterprise on Kubernetes container images
* Authorization files for ArcGIS Enterprise software
* SSL certificates for the ArcGIS Enterprise site domain names

On Kubernetes platform the workflows use:

* [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) to manage Azure resources
* [Terraform CLI by HashiCorp](https://developer.hashicorp.com/terraform/cli) to provision infrastructure in Azure
* [Helm Charts for ArcGIS Enterprise on Kubernetes](https://links.esri.com/enterprisekuberneteshelmcharts/1.2.0/deploy-guide) to install and configure ArcGIS Enterprise organization
* [Enterprise Admin CLI](../enterprise-admin-cli/README.md) container image to invoke ArcGIS Enterprise Admin services and test the deployment

Basic knowledge of Git and Microsoft Azure is required to use the templates. Knowledge of the other technologies is recommended to modify or extend the templates.  

## Templates

An *ArcGIS Enterprise site* in this context is a group of *deployments* that typically include a [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm) or [ArcGIS Enterprise on Kubernetes deployment](https://enterprise-k8s.arcgis.com/en/latest/deploy/system-architecture.htm) plus [additional server deployments](https://enterprise.arcgis.com/en/get-started/latest/windows/additional-server-deployment.htm) in different roles.

The templates automate provisioning of infrastructure shared by the deployments and ArcGIS Enterprise site deployments operations.

The following templates are available for Microsoft Azure:

* [arcgis-site-core](arcgis-site-core/README.md) - Provision core Azure resources for ArcGIS Enterprise site
* [arcgis-enterprise-k8s](arcgis-enterprise-k8s/README.md) - ArcGIS Enterprise on Kubernetes Deployment in AKS

## Triggering Workflows

By default, the workflows are configured with "workflow_dispatch" event that enables workflows to be triggered manually. To trigger a workflow manually, navigate to the repository on GitHub, click on the "Actions" tab, select the workflow to run, select the branch, and click the "Run workflow" button.

> Note that the deployments may belong to different *environments* such as "production" and "staging". Each environment may have its own branch in the repository. The list of workflows in GitHub Actions page shows only the workflows present in /.github/workflows directory of the "main" branch, but the workflow runs use the workflow files from the selected branch. To enable workflows, copy the workflows' .yaml files from the template's `workflows` directory to `/.github/workflows` directory in both the `main` branch and the environment branch, commit the changes, and push the branches to GitHub.

The workflows can be modified to use other triggering events such as push, pull_request, or schedule. Consider using "schedule" event to schedule backups and "pull_request" event to check the infrastructure changes by "terraform plan" command.

## Configuration Files

The workflows use configuration files to define the parameters of the deployments. The configuration files are in JSON format and are stored in the `/config/azure` directory of the repository. The configuration files must be in the same branch as the workflows that use them.

The configuration files may reference other files such as software authorization files and SSL certificates. The workflows symlink `~/config/` paths to the `config` directory path in the GitHub Actions runner workspace. Keep the referenced files in subdirectories of the `/config` directory and reference them as `~/config/<dir>/<file>`.

## Instructions

The specific guidance for using the templates depends on the use case and may involve various customizations. The following steps just demonstrate the typical use case.

### 1. Create GitHub Repository

[Create a new private GitHub repository](https://github.com/new?template_name=arcgis-gitops&template_owner=Esri&description=ArcGIS%20Enterprise%20on%20Azure&name=arcgis-enterprise) from https://github.com/esri/arcgis-gitops template repository.

Use separate GitHub repositories for each ArcGIS Enterprise site and separate Git branches for different environments.

> When operating multiple similar ArcGIS Enterprise sites, consider first forking and modifying https://github.com/esri/arcgis-gitops template repository and then creating repositories for the sites from the modified template.

### 2. Create Required Azure Resources

Create a service principal in Microsoft Entra ID that will be used by the workflows and assign the required roles to it.

> The templates use the same Azure credentials for all the workflows. To implement the principle of least privilege and enforce separation of duties with appropriate authorization for each interaction with Azure resources, consider modifying the workflows to use different Azure credentials for different workflows. Consider using separate service principals for core infrastructure, deployments infrastructure, and application workflows.  

Create a blob container in Azure storage account for the [Terraform backend](https://developer.hashicorp.com/terraform/language/backend/azurerm).


### 3. GitHub Repository Settings

Configure secrets and variables for GitHub Actions in the repository settings.

#### Secrets

| Name                                  | Description                                    |
|---------------------------------------|------------------------------------------------|
| AZURE_CLIENT_ID                       | Service principal client ID                    |
| AZURE_CLIENT_SECRET                   | Service principal client secret                |
| AZURE_TENANT_ID                       | Microsoft Entra tenant ID                      |
| TERRAFORM_BACKEND_STORAGE_ACCOUNT_KEY | Azure storage account key of Terraform backend |

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

| Name                                   | Description                                       |
|----------------------------------------|---------------------------------------------------|
| AZURE_DEFAULT_REGION                   | Default Azure Region display name                 |
| AZURE_SUBSCRIPTION_ID                  | Azure subscription ID                             |
| TERRAFORM_BACKEND_STORAGE_ACCOUNT_NAME | Azure storage account name of Terraform backend   |
| TERRAFORM_BACKEND_CONTAINER_NAME       | Azure storage container name of Terraform backend |

Run validate-settings-azure GitHub Actions workflow to validate the settings.

> If the GitHub subscription plan supports GitHub Actions Environments, consider [environment secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) to use secrets specific to each environment.

### 4. Use the Templates

Follow the [arcgis-site-core](arcgis-site-core/README.md) template instructions to provision core Azure resources for the ArcGIS Enterprise site.

Consult the README files of the other templates to create and operate the required ArcGIS Enterprise deployments.
