# Common ArcGIS Modules Collection for Ansible

The collection includes common modules and playbooks for ArcGIS installation and configuration.

## Ansible version compatibility

This collection has been tested against following Ansible versions: **>=2.16.6**.

## Included content

### Modules

| Module | Description |
| --- | --- |
| arcgis.common.arcgis_info | Retrieves properteis from ~/.ESRI.properties.<hostname>.<ArcGIS version> file |
| arcgis.common.install_patches | Installs hot fixes and patches for ArcGIS software |
| arcgis.common.s3files | Downloads files from S3 bucket to local directories |

### Playbooks

| Playbook | Description |
| --- | --- |
| arcgis.common.clean | Deletes temporary files and directories |
| arcgis.common.efs_mount | Mounts EFS file system |
| arcgis.common.file | Copies local file to hosts |
| arcgis.common.s3_files | Downloads files from S3 bucket to local directories |
| arcgis.common.system | Configures common ArcGIS Enterprise system requirements |
