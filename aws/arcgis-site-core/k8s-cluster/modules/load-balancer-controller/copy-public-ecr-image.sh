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

# This script copies image from public to private Amazon ECR registries.
#
# Required environment variables:
# AWS_DEFAULT_REGION - The AWS default region

set -e

REPO_WITH_TAG=$1

PUBLIC_REGISTRY_URL=public.ecr.aws
ECR_REPOSITORY_PREFIX=ecr-public
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
REPOSITORY_NAME=$(echo $REPO_WITH_TAG | cut -d: -f1)
TAG=$(echo $REPO_WITH_TAG | cut -d: -f2)
PUBLIC_IMAGE=$PUBLIC_REGISTRY_URL/$REPOSITORY_NAME:$TAG
ECR_REPOSITORY_NAME=$ECR_REPOSITORY_PREFIX/$REPOSITORY_NAME
IMAGE=$ECR_REGISTRY_URL/$ECR_REPOSITORY_NAME:$TAG

aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY_URL

set +e

aws ecr describe-repositories --repository-names "${ECR_REPOSITORY_NAME}" > /dev/null 2>&1

# Create ECR repository if it does not exist   
if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${ECR_REPOSITORY_NAME}" --image-scanning-configuration scanOnPush=true --image-tag-mutability IMMUTABLE
    echo "ECR repository '${ECR_REPOSITORY_NAME}' created."
else
    echo "ECR repository '${ECR_REPOSITORY_NAME}' already exists."
fi    

aws ecr describe-images --repository-name $ECR_REPOSITORY_NAME --image-ids imageTag=$TAG > /dev/null 2>&1

# Copy image to the ECR repository if it does not exist
if [[ $? == 0 ]]; then
    echo "Image $ECR_REPOSITORY_NAME:$TAG is already in the ECR repository"
else
    set -e

    docker pull -q $PUBLIC_IMAGE

    docker tag $PUBLIC_IMAGE $IMAGE

    docker push -q $IMAGE

    docker rmi $PUBLIC_IMAGE $IMAGE > /dev/null 2>&1

    echo "Image $ECR_REPOSITORY_NAME:$TAG copied."
fi
