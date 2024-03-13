# IAM Policies for GitHub Actions Workflows

User managed IAM policies for GitHub Actions workflows.

> The policies use conditions that restrict access to resources tagged with Key=ArcGISSiteId,Value=arcgis-enterprise. If the site id is not arcgis-enterprise or the policy will be used with more than one site, then the policy documents must be updated to use the site Ids.

## Creating IAM Policies using AWS CLI

```shell
aws iam create-policy --policy-name ArcGISEnterpriseApplication --policy-document file://ArcGISEnterpriseApplication.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for ArcGIS Enterprise applications management workflows"

aws iam create-policy --policy-name ArcGISEnterpriseDestroy --policy-document file://ArcGISEnterpriseDestroy.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for destroying resources created by ArcGIS Enterprise infrastructure and application management workflows"

aws iam create-policy --policy-name ArcGISEnterpriseImage --policy-document file://ArcGISEnterpriseImage.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for creating EC2 AMIs for ArcGIS Enterprise deployments"

aws iam create-policy --policy-name ArcGISEnterpriseInfrastructure --policy-document file://ArcGISEnterpriseInfrastructure.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for ArcGIS Enterprise infrastructure management workflows"

aws iam create-policy --policy-name ArcGISSiteCore --policy-document file://ArcGISSiteCore.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for arcgis-site-core-aws workflow"

aws iam create-policy --policy-name ArcGISSiteCoreDestroy --policy-document file://ArcGISSiteCoreDestroy.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for arcgis-site-core-aws-destroy workflow" 

aws iam create-policy --policy-name ArcGISK8sCluster --policy-document file://ArcGISK8sCluster.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for arcgis-site-k8s-cluster-aws workflow"

aws iam create-policy --policy-name ArcGISK8sClusterDestroy --policy-document file://ArcGISK8sClusterDestroy.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for arcgis-site-k8s-cluster-aws-destroy workflow"

aws iam create-policy --policy-name ArcGISEnterpriseK8s --policy-document file://ArcGISEnterpriseK8s.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for arcgis-enterprise-k8s-aws-* workflows"

aws iam create-policy --policy-name TerraformBackend --policy-document file://TerraformBackend.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for Terraform S3 backend"
```

Attach the required policies to the IAM user used to run the GitHub Actions workflows.

```shell
aws iam attach-user-policy --policy-arn <policy ARN> --user-name gitops
```
