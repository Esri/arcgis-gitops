# ArcGIS Server Collection for Ansible

The collection includes modules and playbooks used to install and configure ArcGIS Server.

## Ansible version compatibility

This collection has been tested against following Ansible versions: **>=2.16.6**.

## Included content

### Modules

| Module | Description |
| --- | --- |
| arcgis.server.configure_https | Configures SSL certificates of ArcGIS Server machine |
| arcgis.server.create_site | Creates a new ArcGIS Server site |
| arcgis.server.join_site | Joins an existing ArcGIS Server site |
| arcgis.server.set_system_properties | Sets system properties of ArcGIS Server site |
| arcgis.server.unregister_web_adaptors | Unregisters all Web Adaptors from ArcGIS Server site |

### Playbooks

| Playbook | Description |
| --- | --- |
| arcgis.server.fileserver | Configures file server for ArcGIS Server |
| arcgis.server.firewalld | Configures firewalld for ArcGIS Server |
| arcgis.server.install | Installs ArcGIS Server |
| arcgis.server.node | Configures ArcGIS Server on nodes |
| arcgis.server.patch | Installs patches for ArcGIS Server |
| arcgis.server.primary | Creates an ArcGIS Server site |
| arcgis.server.s3_backup | Backs up an ArcGIS Server site to S3 bucket |
| arcgis.server.s3_restore | Restores an ArcGIS Server site from a backup in S3 bucket |
| arcgis.server.unregister_wa | Unregisters ArcGIS Web Adaptors from ArcGIS Server site |
