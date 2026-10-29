#!/bin/bash

# Copyright 2026 Esri
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

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <manifest file path> <ArcGIS version> <enterprise ID>" >&2
    exit 1
fi

MANIFEST_PATH=$1
ARCGIS_VERSION=$2
ENTERPRISE_ID=$3
for REQUIRED_COMMAND in az jq skopeo; do
    command -v "$REQUIRED_COMMAND" > /dev/null
done

IMAGE_LIST=$(jq -er --arg version "$ARCGIS_VERSION" '
    [.versions[] | select(.version == $version) | .containers[].image] | unique |
    if length == 0 then error("No images found for requested ArcGIS version")
    elif all(.[]; type == "string" and test("^[^[:space:]:]+:[^[:space:]:]+$")) then .[]
    else error("Invalid image reference in manifest") end
' "$MANIFEST_PATH")
mapfile -t IMAGES <<< "$IMAGE_LIST"

: "${ARM_CLIENT_ID:?}" "${ARM_CLIENT_SECRET:?}" "${ARM_TENANT_ID:?}"
: "${CONTAINER_REGISTRY_ORG:?}" "${CONTAINER_REGISTRY_USER:?}" "${CONTAINER_REGISTRY_PASSWORD:?}"
: "${ACR_REPOSITORY_PREFIX:?}"
az login --service-principal --username "$ARM_CLIENT_ID" --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID" --output none

VAULT_NAMES=$(az resource list --resource-group "$ENTERPRISE_ID-infrastructure-core" \
    --resource-type Microsoft.KeyVault/vaults --query '[].name' --output json)
VAULT_NAME=$(jq -er 'if length == 1 then .[0] else error("Expected one enterprise Key Vault") end' <<< "$VAULT_NAMES")
ACR_NAME=$(az keyvault secret show --name acr-name --vault-name "$VAULT_NAME" --query value --output tsv)
ACR_LOGIN_SERVER=$(az keyvault secret show --name acr-login-server --vault-name "$VAULT_NAME" --query value --output tsv)

umask 077
AUTH_DIR=$(mktemp -d)
trap 'rm -rf -- "$AUTH_DIR"' EXIT
AUTH_FILE=$AUTH_DIR/auth.json
printf '%s' "$CONTAINER_REGISTRY_PASSWORD" | skopeo login --authfile "$AUTH_FILE" \
    --username "$CONTAINER_REGISTRY_USER" --password-stdin docker.io
ACR_TOKEN=$(az acr login --name "$ACR_NAME" --expose-token --query accessToken --output tsv)
printf '%s' "$ACR_TOKEN" | skopeo login --authfile "$AUTH_FILE" \
    --username 00000000-0000-0000-0000-000000000000 --password-stdin "$ACR_LOGIN_SERVER"
unset ACR_TOKEN

REPOSITORIES=$(az acr repository list --name "$ACR_NAME" --output json)
echo "Found ${#IMAGES[@]} images."
echo "Copying images from DockerHub org $CONTAINER_REGISTRY_ORG to $ACR_LOGIN_SERVER..."

for REPO_WITH_TAG in "${IMAGES[@]}"
do
    REPO=${REPO_WITH_TAG%:*}
    TAG=${REPO_WITH_TAG##*:}
    REPOSITORY_NAME=$ACR_REPOSITORY_PREFIX/$CONTAINER_REGISTRY_ORG/$REPO

    if jq -e --arg repository "$REPOSITORY_NAME" 'index($repository) != null' <<< "$REPOSITORIES" > /dev/null; then
        TAGS=$(az acr repository show-tags --name "$ACR_NAME" --repository "$REPOSITORY_NAME" --output json)
        if jq -e --arg tag "$TAG" 'index($tag) != null' <<< "$TAGS" > /dev/null; then
            echo "Image $REPOSITORY_NAME:$TAG is already in the ACR repository"
            continue
        fi
    fi

    skopeo copy --authfile "$AUTH_FILE" --override-os linux --override-arch amd64 \
        "docker://docker.io/$CONTAINER_REGISTRY_ORG/$REPO_WITH_TAG" \
        "docker://$ACR_LOGIN_SERVER/$REPOSITORY_NAME:$TAG"
    REPOSITORIES=$(jq --arg repository "$REPOSITORY_NAME" '. + [$repository] | unique' <<< "$REPOSITORIES")
    echo "Image $REPOSITORY_NAME:$TAG copied."
done