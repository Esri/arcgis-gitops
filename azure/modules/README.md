# Terraform Child Modules

A Terraform module can call other modules to include their resources into the configuration. A module that has been called by another module is often referred to as a *child module*. Child modules can be called multiple times within the same configuration, and multiple configurations can use the same child module.

* [az_copy_files](az_copy_files/README.md) - copies files from local file system, public URLs, and, My Esri repository to the private repository blob storage
* [aznfs_mount](aznfs_mount/README.md) - mounts Azure NFS file system on Azure VMs in a deployment
* [backend_cert](backend_cert/README.md) - generates a PFX certificate for ArcGIS Enterprise services trusted by the Application Gateway
* [bootstrap](bootstrap/README.md) - installs or upgrades Cinc Client and Chef Cookbooks for ArcGIS on the deployment VMs
* [clean_up](clean_up/README.md) - deletes files in specific directories on the deployment VMs
* [loopback_alias](loopback_alias/README.md) - adds the specified hostname to BackConnectionHostNames registry key on the deployment VMs
* [lv_extend](lv_extend/README.md) - extends logical volumes on Azure VMs in a deployment
* [run_chef](run_chef/README.md) - runs Cinc Client in local mode on the deployment VMs
* [enterprise_core_info](enterprise_core_info/README.md) - retrieves names and Ids of core Azure resources from the enterprise Key Vault
