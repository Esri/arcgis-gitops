# IAM Policies for GitHub Actions Workflows

The directory contains user managed IAM policies for the GitHub Actions workflows.

> The ARNs in the policy documents must be updated to use the correct ARN format for the region where the policies will be used. In particular, in AWS GovCloud (US) Regions, ARNs have an identifier that is different from the one in other standard AWS Regions. For all other standard regions, ARNs begin with: `arn:aws`. In the AWS GovCloud (US) Regions, ARNs begin with:`arn:aws-us-gov`.

> The script requires AWS CLI to be installed and configured with the credentials of an IAM user that has permissions to create IAM policies.

## Creating IAM Policies

Use create-iam-policies.sh script to create IAM policies for the GitHub Action workflows using the JSON policy documents.

Allow execution of the scripts in this directory:

```shell
chmod +x *.sh
```

Run the script to create the IAM policies:

```shell
./create-iam-policies.sh
```

## Updating IAM Policies

Use update-iam-policies.sh script to create new versions of the IAM policies created by create-iam-policies.sh script using the updated JSON policy documents:

```shell
./update-iam-policies.sh
```

For base Windows file servers, update the **existing** ArcGISEnterpriseInfrastructure and ArcGISEnterpriseDestroy policies in place; do not create another policy or IAM user. Before updating either version, run the [FR-013 policy preflight](../../specs/002-dedicated-file-server-vm/quickstart.md#aws-iam-policy-preflight-fr-013), obtain IAM-owner review, and check the actual workflow user's attachments, permissions boundary, and applicable SCPs. Sharing a workflow user's credentials combines the permissions of all its attached policies, so review that effective permission set for infrastructure, recovery, and destroy. Only run an AWS apply or destroy after approved disposable create/update/replacement and teardown checks, with rollback evidence. Updating a document locally does not update an attached policy version in AWS.

## Deleting the IAM Policies

Use delete-iam-policies.sh script to delete the IAM policies created by create-iam-policies.sh script:

```shell
./delete-iam-policies.sh
```

## Attaching IAM Policies to the IAM User

To attach the required policies to the IAM user used to run the GitHub Actions workflows you can use the following command:

```shell
aws iam attach-user-policy --policy-arn <policy ARN> --user-name <IAM user name>
```
