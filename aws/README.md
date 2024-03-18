# GitOps Templates for ArcGIS Enterprise on AWS

## Description

The templates provide GitHub Actions workflows for ArcGIS Enterprise operations on [Amazon Web Services (AWS)](https://aws.amazon.com/) for Windows, Linux, and Kubernetes platforms.

The workflows require:

* GitHub.com user account or GitHub Enterprise Server with enabled GitHub Actions
* Amazon Web Services (AWS) account
* ArcGIS Online user account to download ArcGIS Enterprise installation media from [MyEsri](https://my.esri.com)
* Docker Hub account that has access to private repositories with ArcGIS Enterprise on Kubernetes container images.
* Authorization files for ArcGIS Enterprise software
* SSL certificates for the ArcGIS Enterprise site domain names

The workflows use:

* [AWS CLI](https://aws.amazon.com/cli/) to manage AWS resources
* [Packer by HashiCorp](https://developer.hashicorp.com/packer) to build ArcGIS Enterprise EC2 AMIs
* [Terraform CLI by HashiCorp](https://developer.hashicorp.com/terraform/cli) to provision infrastructure in AWS
* [AWS Systems Manager (SSM)](https://aws.amazon.com/systems-manager/) to remotely manage system and application configuration of the EC2 instances
* Python scripts with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) to invoke AWS services and download installation media
* [Cinc Client](https://cinc.sh/) and [Chef Cookbooks for ArcGIS](https://esri.github.io/arcgis-cookbook/) to install and configure ArcGIS Enterprise applications
* [ArcGIS API for Python](https://developers.arcgis.com/python/) to test ArcGIS Enterprise web services

Basic knowledge of Git and AWS is required to use the templates. Knowledge of the other technologies is recommended if you plan to modify or extend the templates.  

## Concepts

An *ArcGIS Enterprise site* in this context is a group of *deployments* that typically include a [base ArcGIS Enterprise deployment](https://enterprise.arcgis.com/en/get-started/latest/windows/base-arcgis-enterprise-deployment.htm) plus [additional server deployments](https://enterprise.arcgis.com/en/get-started/latest/windows/additional-server-deployment.htm) in different roles.

The deployments may belong to different *environments* such as "production" and "staging" or "blue" and "green".

Deployments configured to receive traffic from clients are referred to as *primary*, *active*, or *live*.

### GitOps Templates

The following templates are available for AWS:

* [arcgis-site-core](arcgis-site-core/README.md) - Provision core AWS resources for ArcGIS Enterprise site
* [arcgis-enterprise-base-windows](arcgis-enterprise-base-linux-windows/README.md) - Base ArcGIS Enterprise on Windows deployment operations
* [arcgis-enterprise-base-linux](arcgis-enterprise-base-linux/README.md) - Base ArcGIS Enterprise on Linux deployment operations
* [arcgis-enterprise-k8s](arcgis-enterprise-k8s/README.md) - ArcGIS Enterprise on Kubernetes deployment operations

### IAM Policies

AWS permissions required by the workflows are defined in [IAM policies](iam-policies/README.md) JSON files. Modify the JSON files if needed and use them to create IAM policies.

### Terraform Child Modules

A Terraform module can call other modules to include their resources into the configuration. A module that has been called by another module is often referred to as a *child module*. The templates use a collection of [child modules](./modules/README.md) that can be called multiple times within the same configuration, and multiple configurations can use the same child module.

### Python Scripts

The Terraform child modules and Packer templates use the [python scripts](./scripts/README.md) to invoke AWS and ArcGIS web services.

### Tests

Tests for ArcGIS Enterprise site web services are used to check availability of the services.

> Note that the tests require the web services to be accessible from the GitHub Actions runners.

## Instructions

The specific guidance for using the templates depends on the use case and may involve various customizations. The following steps just demonstrate the typical use case.

### 1. Create GitHub Repository

[Create a new private GitHub repository](https://github.com/new?template_name=arcgis-gitops&template_owner=ArcGIS&description=ArcGIS%20Enterprise%20on%20AWS&name=arcgis-enterprise) from https://github.com/arcgis/arcgis-gitops template repository.

Use separate GitHub repositories for each ArcGIS Enterprise site (organization) and separate branches for different  environments.

Deployments in the site may use different operating systems on the same platform: linux or windows.

### 2. Create Required AWS Resources

Create IAM user that will be used by the workflows and add the required policies to the user.

> The templates use the same AWS credentials for all the workflows. To implement the principle of least privilege and enforce separation of duties with appropriate authorization for each interaction with your AWS resources, consider modifying the workflows to use different AWS credentials for different workflows. In particular, consider using separate IAM users for core infrastructure, deployments infrastructure, and applications workflows.  

Create a private S3 bucket for the [Terraform backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3). Make sure that the IAM user has the [S3 bucket permissions](https://developer.hashicorp.com/terraform/language/settings/backends/s3#s3-bucket-permissions) required by Terraform.

> It is highly recommended that you enable bucket versioning on the S3 bucket to allow for state recovery in the case of accidental deletions and human error.

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

> If your GitHub subscription plan supports GitHub Actions Environments, consider [environment secrets](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) to use secrets specific to each environment.

### 4. Use the Templates

Follow the [arcgis-site-core](arcgis-site-core/README.md) template instructions to provision core AWS resources for the ArcGIS Enterprise site.

Consult the README files of the other templates to create and operate the required ArcGIS Enterprise deployments.

## Disconnected Environments

To prevent the EC2 deployments from accessing the internet, use "isolated" subnets for the EC2 instances. The isolated subnets do not have public IP addresses and are routed only to VPC endpoints of certain AWS services in specific AWS region.

The disconnected deployments cannot access the system and application internet services such as ArcGIS Online, My Esri, Esri license server, package repositories, pollination services, and time services.

The application image builds run in "private" subnets that can access the internet. The image build installs SSM Agents, CloudWatch agents, AWS CLI, and system packages required by the applications. The application update and upgrade workflows use S3 VPC endpoint to access the private repository S3 bucket to get all the required files.

The disconnected deployments must use authorization files that do not require internet access to the Esri license server, such as Esri Secure License File (ESLF) or ECP file (.ecp).  
