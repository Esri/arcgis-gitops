# IAM Policies for GitHub Actions Workflows

The directory contains user managed IAM policies for the GitHub Actions workflows.

> The ARNs in the policy documents must be updated to use the correct ARN format for the region where the policies will be used. In particular, in AWS GovCloud (US) Regions, ARNs have an identifier that is different from the one in other standard AWS Regions. For all other standard regions, ARNs begin with: `arn:aws`. In the AWS GovCloud (US) Regions, ARNs begin with:`arn:aws-us-gov`.

## Prerequisites and Authorization

Install Bash, AWS CLI, and [jq](https://jqlang.github.io/jq/). Configure AWS CLI
with approved operator credentials for the intended account. No credentials
belong in these scripts or policy documents.

Review the JSON policy documents and obtain the appropriate owner approval
before execution. A new default version changes effective permissions for
**every principal attached to that policy**, not just the current deployment.
Permission broadening requires the normal security review and approval.

The creation script calls STS `GetCallerIdentity` to derive the account and ARN
partition. This STS operation does not require an explicit permission grant.
Authorize only the IAM actions needed for the intended path, scoped to the ten
named policies where supported:

| Path | IAM permissions |
| --- | --- |
| Inspect and reuse existing policies | `iam:GetPolicy`, `iam:GetPolicyVersion` |
| Create missing policies with the existing tags | `iam:CreatePolicy`, `iam:TagPolicy` |
| Update a differing document | `iam:ListPolicyVersions`, `iam:CreatePolicyVersion` |
| Update when five versions already exist | `iam:DeletePolicyVersion`, in addition to the update permissions |
| Roll back to a retained version | `iam:SetDefaultPolicyVersion` (separately authorized recovery operation) |

These are operator permissions, not instructions to broaden the workflow
policies in this directory automatically. Existing-policy inspection errors,
including access denied, are failures, not evidence that a policy is missing.

## Creating IAM Policies

Use [create-iam-policies.sh](create-iam-policies.sh) to reconcile all ten
root-path IAM policies with the JSON policy documents in this directory.

Allow execution of the scripts in this directory:

```shell
chmod +x *.sh
```

Confirm the target account, then run the script:

```shell
aws sts get-caller-identity
./create-iam-policies.sh
```

The script resolves policy documents relative to its own location, so it can also
be invoked from another working directory. It validates all ten local JSON
documents before any AWS calls and stops at the first failed operation.

For each named policy:

| Existing state | Action |
| --- | --- |
| Policy is missing (`NoSuchEntity`) | Create it using the existing name, description, and tags. |
| Default document matches the repository | Reuse the policy without creating a version or changing its metadata. |
| Default document differs | Create a new policy version and make it the default; preserve the policy ARN and attachments. |
| Default differs and five versions exist | Delete only the oldest non-default version by creation date, then create the new default. |

Document comparison ignores JSON whitespace and object-key order. Array order
and values remain significant; this is structural comparison, not a general
IAM permission-equivalence analysis. Repeating a successful run against unchanged
documents performs no writes.

The script reports created, unchanged/reused, updated, and pruned-version
outcomes. Existing tags and descriptions are not reconciled. A concurrent
creation detected by `EntityAlreadyExists` is reread once; serialize policy
updates rather than relying on this limited race handling as a lock.

### Version History and Recovery

IAM permits at most five versions of a managed policy. Before running, export
any historical policy documents that must be retained. Updating at the limit
permanently removes the oldest non-default version; the current default is never
selected for deletion.

Operations are not an account-wide transaction. A later failure does not undo
earlier policies' successful changes. If cleanup succeeds but creating the new
version fails, the previous default remains active, but the deleted historical
version is not restored. Inspect the reported policy and default version before
retrying after an ambiguous response.

To roll back, first inspect the available history:

```shell
aws iam list-policy-versions --policy-arn <policy-arn>
```

With approved recovery authorization, select a reviewed, retained version:

```shell
aws iam set-default-policy-version --policy-arn <policy-arn> --version-id <retained-version-id>
```

Also restore the intended document in version control before the next
reconciliation; otherwise, the script will restore the repository's desired
state. If the required version was pruned, recover its exported document through
a reviewed version-creation operation instead. Do not delete and recreate the
policy to resolve a rerun failure.

## Updating IAM Policies

After reviewing and approving JSON changes, rerun
[create-iam-policies.sh](create-iam-policies.sh). Its comparison and bounded
history cleanup apply to existing policies as well as new installations.

The separate legacy [update-iam-policies.sh](update-iam-policies.sh)  unconditionally creates versions, assumes the standard AWS
partition, and does not prune history at the five-version limit:

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
