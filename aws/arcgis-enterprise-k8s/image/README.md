# Copy Container Images from DockerHub to Amazon ECR

Amazon ECR is a fully managed container registry that provides a secure, scalable, and reliable registry for container images on AWS.

Script image-copy-ecr copies the ArcGIS Enterprise on Kubernetes container images from DockerHub to AWS Elastic Container Registry (ECR) repositories in specific AWS account and region.

## Requirements

On the machine where the script is run, the following tools must be installed:

* [AWS CLI](https://aws.amazon.com/cli/)
* [Docker](https://www.docker.com/)
  
The AWS CLI must be configured with the appropriate AWS credentials and region must be set by AWS_DEFAULT_REGION environment variable.

The DockerHub credentials must be set by environment variables `CONTAINER_REGISTRY_USER` and `CONTAINER_REGISTRY_PASSWORD`. The DockerHub container registry organization must be set by environment variable `CONTAINER_REGISTRY_ORG`.

The script requires at least 20GB of free disk space on the machine to temporary store the container images.

## Usage

```bash
chmod +x ./image-copy-ecr.sh
./image-copy-ecr.sh <manifest file path>
```

The Esri-published version manifest is a JSON file that contains a list of images for a specific ArcGIS Enterprise on Kubernetes version, which are to be copied to ECR. This manifest file can be downloaded from a URL specified by the VERSION_MANIFEST_URL property in the `arcgis-enterprise/<version>/setup/.install/arcgis-enterprise/arcgis-enterprise.properties` file, located within the ArcGIS Enterprise on Kubernetes setup scripts for that particular version of ArcGIS Enterprise on Kubernetes.
