# Python Scripts

The Terraform modules and Packer templates use python scripts to invoke Azure and ArcGIS web services.

The scripts require Python 3.9 or later with azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages installed.

The scripts authenticate to Azure using credentials from Azure CLI login or environment variables.

## az_bootstrap

Installs CINC client and ArcGIS Chef Cookbooks on VMs in a deployment with specified roles.

Usage:

```shell
python -m az_bootstrap [-h] [-s SITE_ID] [-d DEPLOYMENT_ID] [-m MACHINE_ROLES] [-c CHEF_CLIENT_URL] [-k CHEF_COOKBOOKS_URL] [-v VAULT_NAME]
```

Options:

```shell
  -h, --help            show this help message and exit
  -s SITE_ID            ArcGIS Enterprise site Id
  -d DEPLOYMENT_ID      ArcGIS Enterprise deployment Id
  -m MACHINE_ROLES      Machine roles
  -c CHEF_CLIENT_URL    Chef client blob store URL
  -k CHEF_COOKBOOKS_URL Chef cookbooks blob store URL
  -v VAULT_NAME         Azure Key Vault name
```
  
## az_clean_up

Deletes temporary files created by Chef runs on the deployment VMs in the specified roles.

Usage:

```shell
python -m az_clean_up [-h] [-s SITE_ID] [-d DEPLOYMENT_ID] [-m MACHINE_ROLES] [-p]
                      [-u] [-f DIRECTORIES] [-v VAULT_NAME]
```

Options:

```shell
  -h, --help        show this help message and exit
  -s SITE_ID        Site Id
  -d DEPLOYMENT_ID  Deployment Id
  -m MACHINE_ROLES  Machine roles
  -p                Run sysprep script
  -u                Uninstall Chef/Cinc Client
  -f DIRECTORIES    Comma-separated list of local directories to clean up        
  -v VAULT_NAME     Azure Key Vault name
```

## az_copy_files

Copies files from local file system, public URLs, and, My Esri, and ArcGIS
patch repositories to Azure Blob Storage.

Usage:

```shell
python -m az_copy_files [-h] [-a STORAGE_ACCOUNT_BLOB_ENDPOINT]
                        [-c CONTAINER_NAME] [-u USERNAME] [-p PASSWORD] -f FILES
```

Options:

```shell
  -h, --help            show this help message and exit
  -a STORAGE_ACCOUNT_BLOB_ENDPOINT
                        Azure Storage Account Blob Endpoint
  -c CONTAINER_NAME     Azure Blob Storage Container Name
  -u USERNAME           My Esri user name
  -p PASSWORD           My Esri user password
  -f FILES              Index JSON file path
```

## az_run_chef

Runs Chef Client in solo mode on the deployment VMs in the specified roles.

Usage:

```shell
python -m az_run_chef [-h] [-s SITE_ID] [-d DEPLOYMENT_ID] [-m MACHINE_ROLES]
                      [-j JSON_ATTRIBUTES_SECRET] [-e EXECUTION_TIMEOUT]
                      [-v VAULT_NAME] [-l LOG_LEVEL]
```

Options:

```shell
  -h, --help            show this help message and exit
  -s SITE_ID            Site Id
  -d DEPLOYMENT_ID      Deployment Id
  -m MACHINE_ROLES      Machine roles
  -j JSON_ATTRIBUTES_SECRET
                        Key Vault secret name of role attributes
  -e EXECUTION_TIMEOUT  Execution timeout (seconds)
  -v VAULT_NAME         Azure Key Vault name
  -l LOG_LEVEL          Log level
```

## delete_deployment_images

Deletes VM images used by the specified deployment and Key Vault secrets referencing the images.

Usage:

```shell
python -m delete_deployment_images [-h] -s SITE_ID -d DEPLOYMENT_ID -u SUBSCRIPTION_ID
```

Options:

```shell
  -h, --help          show this help message and exit
  -s SITE_ID          ArcGIS Enterprise site Id
  -d DEPLOYMENT_ID    ArcGIS Enterprise deployment Id
  -u SUBSCRIPTION_ID  Azure Subscription Id
```

## publish_artifact

Retrieves VM image Id from packer-manifest.json file and saves in Azure Key Vault secret.

Usage:

```shell
python -m publish_artifact [-h] [-v VAULT_NAME] [-s SECRET_NAME] [-f MANIFEST]
                           [-r PACKER_RUN_UUID]
```

Options:

```shell
  -h, --help          show this help message and exit
  -v VAULT_NAME       Key Vault name
  -s SECRET_NAME      Key Vault secret name
  -f MANIFEST         packer-manifest.json file path
  -r PACKER_RUN_UUID  Packer run UUID
```

## test_azure_credentials

Tests Azure credentials configured in the system by accessing the specified blob container.

Usage:

```shell
 python -m test_azure_credentials [-h] -a ACCOUNT_NAME -c CONTAINER_NAME
```

Options:

```shell
  -h, --help         show this help message and exit
  -a ACCOUNT_NAME    Storage account name
  -c CONTAINER_NAME  Blob container name
```

## token_service_client

Generates token for the specified user credentials.

Usage:

```shell
python -m token_service_client.py [-h] [-s TOKEN_SERVICE_URL] [-u USERNAME] [-p PASSWORD] [-e EXPIRATION]
```

Options:

```shell
  -h, --help            show this help message and exit
  -s TOKEN_SERVICE_URL  Token service URL
  -u USERNAME           User name
  -p PASSWORD           User password
  -e EXPIRATION         Token expiration in seconds
```
