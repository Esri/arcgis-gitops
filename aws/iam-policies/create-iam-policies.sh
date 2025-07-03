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

# The script creates IAM policies for the GitHub Action workflows using the JSON policy documents
# located in the same directory as this script.

aws iam create-policy --policy-name ArcGISEnterpriseApplication --policy-document file://ArcGISEnterpriseApplication.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for ArcGIS Enterprise applications management workflows" --output text
aws iam create-policy --policy-name ArcGISEnterpriseDestroy --policy-document file://ArcGISEnterpriseDestroy.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for destroying resources created by ArcGIS Enterprise infrastructure and application management workflows" --output text
aws iam create-policy --policy-name ArcGISEnterpriseImage --policy-document file://ArcGISEnterpriseImage.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for creating EC2 AMIs for ArcGIS Enterprise deployments" --output text
aws iam create-policy --policy-name ArcGISEnterpriseInfrastructure --policy-document file://ArcGISEnterpriseInfrastructure.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for ArcGIS Enterprise infrastructure management workflows" --output text
aws iam create-policy --policy-name ArcGISEnterpriseK8s --policy-document file://ArcGISEnterpriseK8s.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for ArcGIS Enterprise on Kubernetes workflows" --output text
aws iam create-policy --policy-name ArcGISSiteCore --policy-document file://ArcGISSiteCore.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for site-core-aws workflow" --output text
aws iam create-policy --policy-name ArcGISSiteCoreDestroy --policy-document file://ArcGISSiteCoreDestroy.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for site-core-aws-destroy workflow" --output text
aws iam create-policy --policy-name ArcGISSiteK8sCluster --policy-document file://ArcGISSiteK8sCluster.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for site-k8s-cluster-aws workflow" --output text
aws iam create-policy --policy-name ArcGISSiteK8sClusterDestroy --policy-document file://ArcGISSiteK8sClusterDestroy.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for site-k8s-cluster-aws-destroy workflow" --output text
aws iam create-policy --policy-name TerraformBackend --policy-document file://TerraformBackend.json --tags Key=ArcGISSiteId,Value=arcgis --description "The policy for Terraform S3 backend" --output text