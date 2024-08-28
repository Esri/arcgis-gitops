# ArcGIS Modules Collection for Windows platform

The collection includes common modules and playbooks for ArcGIS installation and configuration on Windows.

## Ansible version compatibility

This collection has been tested against following Ansible versions: **>=2.16.6**.

## Included content

### Modules

| Module | Description |
| --- | --- |
| arcgis.windows.s3files | Downloads files from S3 bucket to local directories |

### Playbooks

| Playbook | Description |
| --- | --- |

| arcgis.windows.bootstrap | Installs ArcGIS PowerShell module on the machine |
| arcgis.windows.clean | Delete temporary files and directories |
| arcgis.windows.file | Copy local file to hosts |
| arcgis.windows.invoke_arcgis_configuration | Runs Invoke-ArcGISConfiguration cmdlet |
| arcgis.windows.s3_files | Downloads files from S3 bucket to local directories |
| arcgis.windows.sysprep | Sysprep the machine |
