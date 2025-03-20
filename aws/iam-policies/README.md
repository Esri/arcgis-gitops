# IAM Policies for GitHub Actions Workflows

User managed IAM policies for GitHub Actions workflows.

> The ARNs in the policy documents must be updated to use the correct ARN format for the region where the policies will be used. In particular, in AWS GovCloud (US) Regions, ARNs have an identifier that is different from the one in other standard AWS Regions. For all other standard regions, ARNs begin with: `arn:aws`. In the AWS GovCloud (US) Regions, ARNs begin with:`arn:aws-us-gov`.

## Creating IAM Policies using AWS CLI

```shell
aws iam create-policy --policy-name ArcGISEnterpriseApplication --policy-document file://ArcGISEnterpriseApplication.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for ArcGIS Enterprise applications management workflows"

aws iam create-policy --policy-name ArcGISEnterpriseDestroy --policy-document file://ArcGISEnterpriseDestroy.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for destroying resources created by ArcGIS Enterprise infrastructure and application management workflows"

aws iam create-policy --policy-name ArcGISEnterpriseImage --policy-document file://ArcGISEnterpriseImage.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for creating EC2 AMIs for ArcGIS Enterprise deployments"

aws iam create-policy --policy-name ArcGISEnterpriseInfrastructure --policy-document file://ArcGISEnterpriseInfrastructure.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for ArcGIS Enterprise infrastructure management workflows"

aws iam create-policy --policy-name ArcGISSiteCore --policy-document file://ArcGISSiteCore.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for site-core-aws workflow"

aws iam create-policy --policy-name ArcGISSiteCoreDestroy --policy-document file://ArcGISSiteCoreDestroy.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for site-core-aws-destroy workflow" 

aws iam create-policy --policy-name ArcGISSiteK8sCluster --policy-document file://ArcGISSiteK8sCluster.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for site-k8s-cluster-aws workflow"

aws iam create-policy --policy-name ArcGISSiteK8sClusterDestroy --policy-document file://ArcGISSiteK8sClusterDestroy.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for site-k8s-cluster-aws-destroy workflow"

aws iam create-policy --policy-name ArcGISEnterpriseK8s --policy-document file://ArcGISEnterpriseK8s.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for enterprise-k8s-aws-* workflows"

aws iam create-policy --policy-name TerraformBackend --policy-document file://TerraformBackend.json --tags Key=ArcGISSiteId,Value=arcgis-enterprise --description "The policy for Terraform S3 backend"
```

Attach the required policies to the IAM user used to run the GitHub Actions workflows.

```shell
aws iam attach-user-policy --policy-arn <policy ARN> --user-name gitops
```
