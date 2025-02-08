#!/bin/bash

# Copyright 2024 Esri
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

# This script builds container image for Enterprise Admin CLI and pushes it to
# private container repository of the site.
#
# On the machine where the script is executed:
#
# * Azure CLI and Docker must be installed
# * Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID, and ARM_CLIENT_SECRET environment variables.

set -e

ACR_REPOSITORY_NAME=$1
TAG=$2
BUILD_CONTEXT_PATH=$3
SITE_ID=$4

az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

VAULT_NAME=$(az resource list --resource-group $SITE_ID-infrastructure-core --resource-type=Microsoft.KeyVault/vaults --query "[].{name:name}" -o tsv)
ACR_NAME=$(az keyvault secret show --name acr-name --vault-name $VAULT_NAME --query value -o tsv)
ACR_LOGIN_SERVER=$(az keyvault secret show --name acr-login-server --vault-name $VAULT_NAME --query value -o tsv)

az acr login --name $ACR_NAME

IMAGE_TAG=$ACR_LOGIN_SERVER/$ACR_REPOSITORY_NAME:$TAG
  
docker build -t $IMAGE_TAG $BUILD_CONTEXT_PATH
docker push $IMAGE_TAG

echo "Image $IMAGE_TAG pushed to $ACR_NAME container registry."
