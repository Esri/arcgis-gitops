# Scripts for Provisioning Container Images in Amazon ECR

The scripts in this directory are used to build and push the Enterprise Admin CLI container image to a private ECR repository and copy ArcGIS Enterprise for Kubernetes images from DockerHub registry to private Amazon ECR repositories in the AWS region.

## Requirements

On the machine where the scripts are run, the following tools must be installed:

* [AWS CLI](https://aws.amazon.com/cli/)
* [Docker](https://www.docker.com/)
  
The AWS CLI must be configured with the appropriate AWS credentials and region must be set by AWS_DEFAULT_REGION environment variable.

## build-admin-cli-image.sh

Builds container image for Enterprise Admin CLI and pushes it to private ECR repository in the AWS region.

```bash
chmod +x ./build-admin-cli-image.sh
./build-admin-cli-image.sh <ECR repository name> <build context path>
```

## copy-docker-hub-images.sh

Copies ArcGIS Enterprise for Kubernetes images from DockerHub registry to private Amazon ECR repositories in the AWS region.

The DockerHub credentials must be set by environment variables `CONTAINER_REGISTRY_USER` and `CONTAINER_REGISTRY_PASSWORD`. The DockerHub container registry organization must be set by environment variable `CONTAINER_REGISTRY_ORG`.

`ECR_REPOSITORY_PREFIX` environment variable must be set to the prefix of the ECR repository name that matches the value "of ecr_repository_prefix" setting used for the k8s-cluster configuration.

```bash
chmod +x ./copy-docker-hub-images.sh
./copy-docker-hub-images.sh <manifest file path>
```

The Esri-published version manifest is a JSON file that contains a list of images for a specific ArcGIS Enterprise on Kubernetes version, which are to be copied to ECR. This manifest file can be downloaded from a URL specified by the VERSION_MANIFEST_URL property in the `arcgis-enterprise/<version>/setup/.install/arcgis-enterprise/arcgis-enterprise.properties` file, located within the ArcGIS Enterprise on Kubernetes setup scripts for that particular version of ArcGIS Enterprise on Kubernetes.

> The script requires at least 20GB of free disk space on the machine to temporary store the container images.
