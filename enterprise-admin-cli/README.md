# ArcGIS Enterprise Admin CLI

ArcGIS Enterprise Admin CLI is a command line interface for ArcGIS Enterprise administration.

The CLI provides:

* Commands for system-level ArcGIS Enterprise configuration management using [ArcGIS Enterprise Administrator API](https://developers.arcgis.com/rest/enterprise-administration/enterprise/overview-of-the-arcgis-enterprise-admin-api.htm), and
* Scripts for application-level ArcGIS Enterprise administration using [ArcGIS API for Python](https://developers.arcgis.com/python/).

## Building and Running the CLI

The CLI requires Docker to build image and execute the commands.

To build the image, run:

```text
docker build -t arcgis-enterprise-cli:latest .
```

To execute a CLI command, run:

```text
docker run arcgis-enterprise-cli:latest gis <command> [arguments]
```

The ArcGIS Enterprise endpoint URL and user credentials can be provided either in the command line arguments or environment variables (using `-e` option of `docker run`).

The following environment variables are supported:

* `ARCGIS_ENTERPRISE_URL` - ArcGIS Enterprise URL (`https://organization.domain.com/<context>`)
* `ARCGIS_ENTERPRISE_USER` - ArcGIS Enterprise user name
* `ARCGIS_ENTERPRISE_PASSWORD` - ArcGIS Enterprise user password

## create-backup command

Creates backup of the organization.

Usage:

```text
gis create-backup [-h] [--url URL] [-u USER] [-p PASSWORD]
                  [--store STORE] --backup BACKUP --passcode PASSCODE 
                  [--description DESCRIPTION] [--retention RETENTION]
                  [--wait]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --store STORE         backup store name (if not specified - the default store is used)
  --backup BACKUP       backup name
  --passcode PASSCODE   pass code that will be used to encrypt content of the backup
  --description DESCRIPTION
                        backup description
  --retention RETENTION backup retention time (days)
  --wait                wait until the backup is completed
```

## generate-token command

Generates an access token in exchange for user credentials.

Usage:

```text
gis generate-token [-h] [--url URL] [-u USER] [-p PASSWORD] [--expiration EXPIRATION]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --expiration EXPIRATION
                        The token expiration time in minutes
```

## get-backup-stores command

Returns backup stores registered with the deployment.

Usage:

```text
gis get-backup-stores [-h] [--url URL] [-u USER] [-p PASSWORD]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
```

## get-dr-settings command

Returns the currently configured disaster recovery settings.

Usage:

```text
gis get-dr-settings [-h] [--url URL] [-u USER] [-p PASSWORD]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
```

## register-az-backup-store command

Registers or updates backup store in Microsoft Azure blobs

Usage:

```text
gis register-az-backup-store [-h] [--url URL] [-u USER] [-p PASSWORD]
                             --store STORE --storage-account STORAGE_ACCOUNT
                             [--account-endpoint-url ACCOUNT_ENDPOINT_URL]
                             --client-id CLIENT_ID [--root ROOT] [--is-default]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --store STORE         backup store name
  --storage-account STORAGE_ACCOUNT 
                        Azure storage account name
  --account-endpoint-url ACCOUNT_ENDPOINT_URL
                        Blob service endpoint URL
  --client-id CLIENT_ID User-assigned managed identity client Id
  --root ROOT           blob container root directory  
  --is-default          make the store default
```

## register-pv-backup-store command

Registers or updates backup store in a persistent volume.

Usage:
  
```text
gis register-pv-backup-store [-h] [--url URL] [-u USER] [-p PASSWORD] 
                             --store STORE --storage-class STORAGE_CLASS --size SIZE
                             [--is-dynamic] [--is-default] [--label KEY=VALUE [KEY=VALUE ...]]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --store STORE         backup store name
  --storage-class STORAGE_CLASS
                        backup volume storage class
  --size SIZE           backup volume size (e.g. 64Gi)
  --is-dynamic          use dynamic volume provisioning type
  --is-default          make the store default
  --label KEY=VALUE [KEY=VALUE ...]
                        key=value pair to identify and bind to a persistent volume
```

## register-s3-backup-store command

Registers or updates S3 backup store.

Usage:

```text
gis register-s3-backup-store [-h] [--url URL] [-u USER] [-p PASSWORD]
                             --store STORE --bucket BUCKET --region REGION
                             [--root ROOT] [--is-default]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --store STORE         backup store name
  --bucket BUCKET       S3 bucket name
  --region REGION       S3 bucket region
  --root ROOT           S3 bucket root directory
  --is-default          make the store default
```

## restore-organization command

Restores the organization to the state it was in when the specified backup was created.

Usage:

```text
gis restore-organization [-h] [--url URL] [-u USER] [-p PASSWORD]
                         [--store STORE] [--backup BACKUP] --passcode PASSCODE 
                         [--wait] [--timeout TIMEOUT]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --store STORE         backup store name (if not specified - the default store is used)
  --backup BACKUP       backup name (if not specified - the latest backup is used)
  --passcode PASSCODE   pass code used to encrypt the backup
  --wait                wait until the restore operation is completed
  --timeout TIMEOUT     restore operation timeout (seconds)
```

## update-dr-settings command

Updates the disaster recovery settings.

Usage:

```text
gis update-dr-settings [-h] [--url URL] [-u USER] [-p PASSWORD]
                       --storage-class STORAGE_CLASS --size SIZE
                       [--timeout TIMEOUT]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
  --storage-class STORAGE_CLASS
                        staging volume storage class
  --size SIZE           staging volume size (e.g. 64Gi)
  --timeout TIMEOUT     backup job timeout (seconds)
```

## test-nb-admin script

Tests ArcGIS Notebook Server admin endpoint accessibility.

Usage:

```text
gis test-nb-admin [-h] [--nb-url NB_URL] [--url URL] [-u USER] [-p PASSWORD]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --nb-url NB_URL       ArcGIS Notebook Server URL  
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
```

## test-publish-csv script

Tests ArcGIS Enterprise deployment by publishing feature service from CSV file.

Usage:

```text
gis test-publish-csv [-h] [--url URL] [-u USER] [-p PASSWORD]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Enterprise URL
  -u USER, --user USER  ArcGIS Enterprise user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Enterprise user password
```

## test-server-admin script

Tests ArcGIS Server admin endpoint accessibility.

Usage:

```text
gis test-server-admin [-h] [--url URL] [-u USER] [-p PASSWORD]
```

Arguments:

```text
  -h, --help            show this help message and exit
  --url URL             ArcGIS Server URL
  -u USER, --user USER  ArcGIS Server administrator user name
  -p PASSWORD, --password PASSWORD
                        ArcGIS Server administrator user password
```
