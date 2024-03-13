# Core AWS Resources for ArcGIS Enterprise Site

The template provides workflows for provisioning:

* Networking, storage, and identity AWS resource shared across multiple deployments of an ArcGIS Enterprise site,
* AWS resources required for ArcGIS Enterprise site configuration management using [Chef Cookbooks for ArcGIS](https://esri.github.io/arcgis-cookbook/), and
* Amazon Elastic Kubernetes Service (EKS) cluster that meets ArcGIS Enterprise on Kubernetes system requirements.

Before running the template workflows, configure the GitHub repository settings as described in the general [Instructions](../README.md#instructions) section.

To enable the template's workflows, copy the .yml files from the template's `workflows` directory to `/.github/workflows` directory in the `main` branch, commit the changes, and push the branch to GitHub.

> To prevent accidental destruction of the resources, don't enable arcgis-site-core-aws-destroy and arcgis-site-k8s-cluster-aws-destroy workflows until it is necessary.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Create Core AWS Resources

GitHub Actions workflow **arcgis-site-core-aws** creates core AWS resources for an ArcGIS Enterprise site.

The workflows uses [infrastructure-core](infrastructure-core/README.md) and [automation-chef](automation-chef/README.md) Terraform modules with [infrastructure-core.tfvars.json](config/infrastructure-core.tfvars.json), [automation-chef.tfvars.json](config/automation-chef.tfvars.json), and [automation-chef-files.json](config/automation-chef-files.json) configuration files.

Required IAM policies:

* TerraformBackend
* ArcGISSiteCore

Instructions:

1. (Optional) Change "isolated_subnets" property in infrastructure-core.tfvars.json file to `true` if the site will use isolated subnets.
2. (Optional) Update "arcgis.repository.files" map in automation-chef-files.json to specify the locations of Cinc Client setups and Chef Cookbooks for ArcGIS archives that will be copied into the private repository S3 bucket.
3. (Optional) Update "chef_client_paths" and "images" maps in automation-chef.tfvars.json file to specify the Cinc Client setups S3 paths and EC2 AMIs for the operating systems Ids that will be used by the site. Remove entries for operating systems that will not be used by the site.
4. Commit the changes to the `main` branch and push the branch to GitHub.
5. Run arcgis-site-core-aws workflow using the `main` branch.

## Deploy EKS Cluster

GitHub Actions workflow **arcgis-site-k8s-cluster-aws** deploys Amazon EKS cluster
that meets ArcGIS Enterprise on Kubernetes system requirements.

The workflows uses [k8s-cluster](k8s-cluster/README.md) Terraform module with [k8s-cluster.tfvars.json](../../config/aws/arcgis-site-core/k8s-cluster.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISSiteK8sCluster

Instructions:

1. Create an EC2 key pair in the selected AWS region and set "key_name" property in the config file to the key pair name. Save the private key in a secure location.
2. Set "eks_version" property to the required EKS version.
3. Set "node_groups" property to the required node groups configuration.
4. Commit the changes to the `main` branch and push the branch to GitHub.
5. Run arcgis-site-k8s-cluster-aws workflow using the `main` branch.

## Destroy EKS Cluster

GitHub Actions workflow **arcgis-site-k8s-cluster-aws-destroy** destroys Amazon EKS cluster created by arcgis-site-k8s-cluster-aws workflow.

The workflows uses [k8s-cluster](k8s-cluster/README.md) Terraform module with [k8s-cluster.tfvars.json](../../config/aws/arcgis-site-core/k8s-cluster.tfvars.json) config file.

Required IAM policies:

* TerraformBackend
* ArcGISSiteK8sClusterDestroy

Instructions:

1. Run arcgis-site-k8s-cluster-aws-destroy workflow using the `main` branch.

## Destroy Core AWS Resources

GitHub Actions workflow **arcgis-site-core-aws-destroy** destroys the AWS resources created by arcgis-site-core-aws workflow.

The workflows uses [infrastructure-core](infrastructure-core/README.md) and [automation-chef](automation-chef/README.md) Terraform modules with [infrastructure-core.tfvars.json](config/infrastructure-core.tfvars.json) and [automation-chef.tfvars.json](config/automation-chef.tfvars.json) configuration files.

Required IAM policies:

* TerraformBackend
* ArcGISSiteCoreDestroy

Instructions:

1. Run arcgis-site-core-aws-destroy workflow using the `main` branch.

> Along with all other resources, arcgis-site-core-aws-destroy workflow destroys backups of all deployments.
