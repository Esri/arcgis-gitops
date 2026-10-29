#!/bin/bash

# Copyright 2024-2026 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script copies ArcGIS Enterprise for Kubernetes images from DockerHub 
# registry to private Amazon ECR repositories.
#
# Required environment variables:
# CONTAINER_REGISTRY_ORG - The container registry organization
# CONTAINER_REGISTRY_USER - The container registry username
# CONTAINER_REGISTRY_PASSWORD - The container registry password
# AWS_DEFAULT_REGION - The AWS default region
# ECR_REPOSITORY_PREFIX - The ECR repository prefix (a.k.a. namespace)

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <manifest file path> <ArcGIS version>" >&2
    exit 1
fi

MANIFEST_PATH=$1
ARCGIS_VERSION=$2
for REQUIRED_COMMAND in aws jq skopeo; do
    command -v "$REQUIRED_COMMAND" > /dev/null
done

IMAGE_LIST=$(jq -er --arg version "$ARCGIS_VERSION" '
    [.versions[] | select(.version == $version) | .containers[].image] | unique |
    if length == 0 then error("No images found for requested ArcGIS version")
    elif all(.[]; type == "string" and test("^[^[:space:]:]+:[^[:space:]:]+$")) then .[]
    else error("Invalid image reference in manifest") end
' "$MANIFEST_PATH")
mapfile -t IMAGES <<< "$IMAGE_LIST"

: "${CONTAINER_REGISTRY_ORG:?}" "${CONTAINER_REGISTRY_USER:?}" "${CONTAINER_REGISTRY_PASSWORD:?}"
: "${AWS_DEFAULT_REGION:?}" "${ECR_REPOSITORY_PREFIX:?}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

umask 077
AUTH_DIR=$(mktemp -d)
trap 'rm -rf -- "$AUTH_DIR"' EXIT
AUTH_FILE=$AUTH_DIR/auth.json
printf '%s' "$CONTAINER_REGISTRY_PASSWORD" | skopeo login --authfile "$AUTH_FILE" \
    --username "$CONTAINER_REGISTRY_USER" --password-stdin docker.io
aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | skopeo login --authfile "$AUTH_FILE" \
    --username AWS --password-stdin "$ECR_REGISTRY_URL"

echo "Found ${#IMAGES[@]} images."
echo "Copying images from DockerHub org $CONTAINER_REGISTRY_ORG to $ECR_REGISTRY_URL..."

for REPO_WITH_TAG in "${IMAGES[@]}"
do
    REPO=${REPO_WITH_TAG%:*}
    TAG=${REPO_WITH_TAG##*:}

    REPOSITORY_NAME=$CONTAINER_REGISTRY_ORG/$REPO
    ECR_REPOSITORY_NAME=$ECR_REPOSITORY_PREFIX/$REPOSITORY_NAME
    IMAGE=$ECR_REGISTRY_URL/$ECR_REPOSITORY_NAME:$TAG

    if AWS_RESULT=$(aws ecr describe-repositories --repository-names "$ECR_REPOSITORY_NAME" 2>&1); then
        echo "ECR repository '${ECR_REPOSITORY_NAME}' already exists."
    elif [[ "$AWS_RESULT" == *"(RepositoryNotFoundException)"* ]]; then
        aws ecr create-repository --repository-name "$ECR_REPOSITORY_NAME" --image-scanning-configuration scanOnPush=true --image-tag-mutability IMMUTABLE
        echo "ECR repository '${ECR_REPOSITORY_NAME}' created."
    else
        printf '%s\n' "$AWS_RESULT" >&2
        exit 1
    fi

    if AWS_RESULT=$(aws ecr describe-images --repository-name "$ECR_REPOSITORY_NAME" --image-ids "imageTag=$TAG" 2>&1); then
        echo "Image $ECR_REPOSITORY_NAME:$TAG is already in the ECR repository"
    elif [[ "$AWS_RESULT" == *"(ImageNotFoundException)"* ]]; then
        skopeo copy --authfile "$AUTH_FILE" --override-os linux --override-arch amd64 \
            "docker://docker.io/$REPOSITORY_NAME:$TAG" "docker://$IMAGE"
        echo "Image $ECR_REPOSITORY_NAME:$TAG copied."
    else
        printf '%s\n' "$AWS_RESULT" >&2
        exit 1
    fi
done
