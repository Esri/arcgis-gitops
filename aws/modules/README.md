# Terraform Child Modules

A Terraform module can call other modules to include their resources into the configuration. A module that has been called by another module is often referred to as a *child module*. Child modules can be called multiple times within the same configuration, and multiple configurations can use the same child module.

* [alb_target_group](alb_target_group/README.md) - creates and configures Application Load Balancer target group
* [ansible_playbook](ansible_playbook/README.md) - runs Ansible playbook on EC2 instances
* [bootstrap](bootstrap/README.md) - installs or upgrades Cinc Client and Chef Cookbooks for ArcGIS on EC2 instances 
* [clean_up](clean_up/README.md) - deletes files in specific directories on EC2 instances
* [cw_agent](cw_agent/README.md) - configures CloudWatch agent on the deployment EC2 instances
* [dashboard](dashboard/README.md) - creates CloudWatch dashboard for deployment monitoring
* [efs_mount](nfs_mount/README.md) - mounts EFS file system targets on EC2 instances in a deployment
* [run_chef](run_chef/README.md) - runs Cinc Client in local mode on EC2 instances
* [s3_copy_files](s3_copy_files/README.md) - copies files from local file system, public URLs, and, My Esri repository to S3 bucket
* [security_group](security_group/README.md) - creates and configures EC2 security group for a deployment
* [site_core_info](site_core_info/README.md) - retrieves names and Ids of core AWS resources from AWS Systems Manager parameters
