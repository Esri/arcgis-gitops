# Quickstart: validating Azure RBAC documentation

Use this checklist when reviewing an Azure workflow README:

1. Confirm the README states the specific roles needed for the workflow, not a generic subscription-wide default.
2. For provisioning workflows, check that the documented roles include `Contributor` and `User Access Administrator` when the workflow assigns RBAC to managed identities or Key Vaults.
3. For Terraform backend state, confirm the storage access role is listed separately as `Storage Blob Data Owner` or the appropriate data-plane role.
4. For application-level workflows, verify that the role set is narrower than a broad `Owner` assignment and matches the workflow’s actual actions.
5. Ensure the documentation clearly distinguishes between management-plane and data-plane permissions.

## Review rule

If a README still says `Owner` at subscription scope without explaining why, treat that as an incomplete least-privilege statement and update it to the workflow-specific role list.