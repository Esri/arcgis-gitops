# Core AWS Resources for ArcGIS Enterprise Site

The template provides workflows for provisioning networking, storage, and identity AWS resource shared across multiple deployments of an ArcGIS Enterprise site as well as AWS resources required for ArcGIS Enterprise site configuration management using [Chef Cookbooks for ArcGIS](https://esri.github.io/arcgis-cookbook/).

Before running the template workflows, configure the GitHub repository settings as described in the [Getting Started](../README.md#instructions) section.

To enable the template's workflows, copy the .yml files from the template's `workflows` directory to `/.github/workflows` directory in the `main` branch, commit the changes, and push the branch to GitHub.

> To prevent accidental destruction of the resources, don't enable arcgis-site-core-aws-destroy workflow until it is necessary.

> Refer to READMEs of the Terraform modules and Packer templates for descriptions of the configuration properties.

## Create Core AWS Resources

GitHub Actions workflow **arcgis-site-core-aws workflow** creates core AWS resources for an ArcGIS Enterprise site.

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

## Destroy Core AWS Resources

GitHub Actions workflow **arcgis-site-core-aws-destroy** destroys the AWS resources created by arcgis-site-core-aws workflow.

The workflows uses [infrastructure-core](infrastructure-core/README.md) and [automation-chef](automation-chef/README.md) Terraform modules with [infrastructure-core.tfvars.json](config/infrastructure-core.tfvars.json) and [automation-chef.tfvars.json](config/automation-chef.tfvars.json) configuration files.

Required IAM policies:

* TerraformBackend
* ArcGISSiteCoreDestroy

Instructions:

1. Run arcgis-site-core-aws-destroy workflow using the `main` branch.

> Along with all other resources, arcgis-site-core-aws-destroy workflow destroys backups of all deployments.
