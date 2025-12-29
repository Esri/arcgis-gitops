#!/bin/bash

# Copyright 2025 Esri
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

# The script updates IAM policies created by create-iam-policies.sh script using the JSON policy documents
# located in the same directory as this script.

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseApplication --policy-document file://ArcGISEnterpriseApplication.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseDestroy --policy-document file://ArcGISEnterpriseDestroy.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseImage --policy-document file://ArcGISEnterpriseImage.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseInfrastructure --policy-document file://ArcGISEnterpriseInfrastructure.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISEnterpriseK8s --policy-document file://ArcGISEnterpriseK8s.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteCore --policy-document file://ArcGISSiteCore.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteCoreDestroy --policy-document file://ArcGISSiteCoreDestroy.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteK8sCluster --policy-document file://ArcGISSiteK8sCluster.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ArcGISSiteK8sClusterDestroy --policy-document file://ArcGISSiteK8sClusterDestroy.json --set-as-default --output text
aws iam create-policy-version --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/TerraformBackend --policy-document file://TerraformBackend.json --set-as-default --output text
