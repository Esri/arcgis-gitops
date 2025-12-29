# IAM Policies for GitHub Actions Workflows

The directory contains user managed IAM policies for the GitHub Actions workflows.

> The ARNs in the policy documents must be updated to use the correct ARN format for the region where the policies will be used. In particular, in AWS GovCloud (US) Regions, ARNs have an identifier that is different from the one in other standard AWS Regions. For all other standard regions, ARNs begin with: `arn:aws`. In the AWS GovCloud (US) Regions, ARNs begin with:`arn:aws-us-gov`.

> The script requires AWS CLI to be installed and configured with the credentials of an IAM user that has permissions to create IAM policies.

## Creating IAM Policies

Use create-iam-policies.sh script create IAM policies for the GitHub Action workflows using the JSON policy documents.

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
