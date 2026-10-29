# Scripts for Provisioning Container Images in Amazon ECR

The scripts in this directory are used to build and push the Enterprise Admin CLI container image to a private ECR repository and copy ArcGIS Enterprise for Kubernetes images from Docker Hub to private Amazon ECR repositories in the AWS region.

## Requirements

On the machine where the scripts are run, the following tools must be installed:

* [AWS CLI](https://aws.amazon.com/cli/)
* [jq](https://jqlang.github.io/jq/)
* [Skopeo](https://github.com/containers/skopeo) for copying ArcGIS images
* [Docker](https://www.docker.com/) for building the Enterprise Admin CLI image only
  
The AWS CLI must be configured with the appropriate AWS credentials and region must be set by AWS_DEFAULT_REGION environment variable.

## build-admin-cli-image.sh

Builds container image for Enterprise Admin CLI and pushes it to a private ECR repository in the AWS region.

```bash
chmod +x ./build-admin-cli-image.sh
./build-admin-cli-image.sh <ECR repository name> <admin CLI version> <build context path>
```

## copy-docker-hub-images.sh

Copies ArcGIS Enterprise for Kubernetes images from DockerHub registry to private Amazon ECR repositories in the AWS region using `skopeo copy`. Image layers are streamed between registries without pulling them into the local Docker daemon or staging complete images on disk. The copy script does not require Docker. The AWS image workflow installs Skopeo and copies images only when `copy_docker_hub_images` is `true` in the image configuration. When the property is `false`, missing, or null, installation and copying are skipped. The Admin CLI image is built independently of this flag.

The Docker Hub credentials must be set by environment variables `CONTAINER_REGISTRY_USER` and `CONTAINER_REGISTRY_PASSWORD`. The Docker Hub container registry organization must be set by environment variable `CONTAINER_REGISTRY_ORG`.

`ECR_REPOSITORY_PREFIX` environment variable must be set to the prefix of the ECR repository name that matches the value of the `ecr_repository_prefix` setting used for the k8s-cluster configuration.

```bash
chmod +x ./copy-docker-hub-images.sh
./copy-docker-hub-images.sh <manifest file path> <ArcGIS version>
```

The Esri-published version manifest is a JSON file that contains a list of images for a specific ArcGIS Enterprise on Kubernetes version, which are to be copied to ECR. This manifest file can be downloaded from a URL specified by the VERSION_MANIFEST_URL property in the `arcgis-enterprise/<version>/setup/.install/arcgis-enterprise/arcgis-enterprise.properties` file, located within the ArcGIS Enterprise on Kubernetes setup scripts for that particular version of ArcGIS Enterprise on Kubernetes.

Images are copied sequentially for Linux/AMD64, preserving the hosted runner's platform selection. Image tags come from the selected version's manifest, including any build suffixes. Destination images retain the naming pattern `<account>.dkr.ecr.<region>.amazonaws.com/<prefix>/<organization>/<image>:<tag>`. Missing repositories are created with scan-on-push enabled and immutable tags; existing tags are skipped. Authentication is stored in a private temporary file that is removed when the script exits, and passwords are supplied through standard input.

## Workflow Configuration

In `config/aws/arcgis-enterprise-k8s/image.vars.json`, set:

* `copy_docker_hub_images`: `true` to enable direct copying; the default `false` preserves the existing cache-only behavior. This flag does not create, disable, or remove Terraform-managed ECR cache rules.
* `arcgis_version`: the exact bundled manifest version, such as `12.1.0`. The workflow selects `./manifests/12.1.0.dat` for that version and fails before installing tools or authenticating if the file is absent. No manifest path setting is required.
* `container_registry_org`: the source Docker Hub organization authorized by your credentials.
* `ecr_repository_prefix`: the ECR destination namespace.

The AWS image workflow template installs Skopeo only when copying is enabled. Configure GitHub secrets `CONTAINER_REGISTRY_USER` and `CONTAINER_REGISTRY_PASSWORD` alongside the existing AWS credentials. Publish the template to `.github/workflows` using the repository's normal workflow setup procedure. The separate Admin CLI Docker build remains enabled.
