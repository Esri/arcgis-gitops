# Terraform Child Modules

A Terraform module can call other modules to include their resources into the configuration. A module that has been called by another module is often referred to as a *child module*. Child modules can be called multiple times within the same configuration, and multiple configurations can use the same child module.

* [bootstrap](bootstrap/README.md) - installs or upgrades Cinc Client and Chef Cookbooks for ArcGIS on the deployment VMs
* [clean_up](clean_up/README.md) - deletes files in specific directories on the deployment VMs
* [run_chef](run_chef/README.md) - runs Cinc Client in local mode on the deployment VMs
* [az_copy_files](az_copy_files/README.md) - copies files from local file system, public URLs, and, My Esri repository to the private repository blob storage
* [site_core_info](site_core_info/README.md) - retrieves names and Ids of core Azure resources from the site Key Vault
