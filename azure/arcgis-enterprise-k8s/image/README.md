# Scripts for Provisioning Container Images in ACR

The scripts in this directory are used to build and push the Enterprise Admin CLI container image to a private ACR repository.

## Requirements

On the machine where the scripts are run, the following tools must be installed:

* Azure CLI and Docker must be installed
* Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID, and ARM_CLIENT_SECRET environment variables.
 
## build-admin-cli-image.sh

Builds container image for Enterprise Admin CLI and pushes it to private ACR repository.

```bash
chmod +x ./build-admin-cli-image.sh
./build-admin-cli-image.sh enterprise-admin-cli <admin CLI version> <build context path> <site ID>
```
