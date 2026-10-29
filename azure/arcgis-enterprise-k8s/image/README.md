# Scripts for Provisioning Container Images in ACR

The scripts in this directory build and push the Enterprise Admin CLI container image to ACR and optionally copy ArcGIS Enterprise for Kubernetes images directly from Docker Hub to ACR.

## Requirements

On the machine where the scripts are run, the following tools must be installed:

* Azure CLI must be installed. Copying images also requires Bash 4 or later, jq, and [Skopeo](https://github.com/containers/skopeo). Docker is required only for the Admin CLI build.
* Azure service principal credentials must be configured by `ARM_CLIENT_ID`, `ARM_TENANT_ID`, and `ARM_CLIENT_SECRET` environment variables. The principal must already be authorized to discover the enterprise Key Vault, read `acr-name` and `acr-login-server`, and list, read, and push images in ACR. These scripts do not grant permissions or enable ACR admin credentials.

## build-admin-cli-image.sh

Builds container image for Enterprise Admin CLI and pushes it to private ACR repository.

```bash
chmod +x ./build-admin-cli-image.sh
./build-admin-cli-image.sh enterprise-admin-cli <admin CLI version> <build context path> <enterprise ID>
```

## copy-docker-hub-images.sh

Streams Linux/AMD64 image layers directly from Docker Hub to ACR using `skopeo copy`, without pulling images into Docker or staging complete images on runner disk. The script discovers the registry through the same enterprise Key Vault as the Admin CLI build. It authenticates to ACR using an exposed Azure CLI access token and stores registry authentication in a private temporary file, removed when the script exits.

Set `CONTAINER_REGISTRY_USER` and `CONTAINER_REGISTRY_PASSWORD` to approved Docker Hub credentials, `CONTAINER_REGISTRY_ORG` to the source organization, and `ACR_REPOSITORY_PREFIX` to the destination namespace. Credentials must come from environment variables or GitHub secrets, not configuration files.

```bash
bash ./copy-docker-hub-images.sh <manifest file path> <ArcGIS version> <enterprise ID>
```

The `manifests` directory contains the Esri-published JSON version manifests. When adding support for another version, add its published manifest to the directory. Published manifests are available from the `VERSION_MANIFEST_URL` property in the ArcGIS Enterprise on Kubernetes setup's `arcgis-enterprise.properties`. The script selects and deduplicates images for the exact manifest version, preserving build-qualified tags. It copies to `<acr-login-server>/<prefix>/<organization>/<image>:<tag>`, skips existing tags, and fails on authentication, registry lookup, or copy errors. ACR creates repositories when images are pushed; the script does not change repository permissions or retention settings.

## Workflow Configuration

In `config/azure/arcgis-enterprise-k8s/image.vars.json`, set:

* `copy_docker_hub_images`: `true` to enable direct copying; the default `false` preserves the existing cache-only behavior. This flag does not create, disable, or remove Terraform-managed ACR cache rules.
* `arcgis_version`: the exact bundled manifest version, such as `12.1.0`. The workflow selects `./manifests/12.1.0.dat` for that version and fails before installing tools or authenticating if the file is absent. No manifest path setting is required.
* `container_registry_org`: the source Docker Hub organization authorized by your credentials.
* `acr_repository_prefix`: the ACR destination namespace.

Pushing images to namespace 'docker-hub/esridocker' matching cache rule 'pullthroughcache' is not supported by ACR. To use the copied images instead of the pull-through cache, change "image_repository_prefix" in organization.tfvars.json file from "docker-hub/esridocker" to "arcgis-enterprise/esridocker".

The Azure image workflow template installs Skopeo only when copying is enabled. Configure GitHub secrets `CONTAINER_REGISTRY_USER` and `CONTAINER_REGISTRY_PASSWORD` alongside the existing Azure credentials. Publish the template to `.github/workflows` using the repository's normal workflow setup procedure. The separate Admin CLI Docker build remains enabled.
