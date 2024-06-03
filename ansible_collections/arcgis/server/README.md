# ArcGIS Server Collection for Ansible

The collection includes modules and playbooks used to install and configure ArcGIS Server.

## Ansible version compatibility

This collection has been tested against following Ansible versions: **>=2.16.6**.

## Included content

### Modules

| Module | Description |
| --- | --- |
| arcgis.server.create_site | Creates a new ArcGIS Server site |
| arcgis.server.join_site | Joins an existing ArcGIS Server site |

### Playbooks

| Playbook | Description |
| --- | --- |
| arcgis.server.fileserver | Configures fileserver for ArcGIS Server |
| arcgis.server.install | Installs ArcGIS Server |
| arcgis.server.node | Configures ArcGIS Server on nodes |
| arcgis.server.patch | Installs patches for ArcGIS Server |
| arcgis.server.primary | Creates an ArcGIS Server site |
| arcgis.server.s3_backup | Backs up an ArcGIS Server site to S3 bucket |
| arcgis.server.s3_files | Downloads setups and patches from S3 bucket to local directories |
| arcgis.server.s3_restore | Restores an ArcGIS Server site from a backup in S3 bucket |
