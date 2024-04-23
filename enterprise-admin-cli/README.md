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

## test-publish-csv command

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
