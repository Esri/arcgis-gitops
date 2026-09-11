# Research: Azure RBAC documentation and least-privilege review

## Summary

The repo’s Azure workflow READMEs currently instruct operators to grant the workflow service principal `Owner` at the subscription scope. That is broader than the access the workflows actually need in most cases and conflicts with the project constitution’s least-privilege requirement.

## Findings

1. The Terraform definitions assign roles to the current principal and managed identities, as well as to storage accounts, Key Vaults, Cosmos DB, Service Bus, and AKS-related resources.
2. Provisioning workflows create and manage shared enterprise resources, so the service principal requires permission to create resources and assign RBAC at the target scope.
3. Data-plane operations such as Terraform backend state access, blob access, and Key Vault secret access require resource-scoped data permissions on the storage account or vault.
4. The repo already distinguishes between workflow types in some READMEs (for example, `Contributor` for application workflows and Azure-specific data roles for storage access). The inconsistency is that several provisioning READMEs use blanket subscription `Owner` language.

## Decision

Use a consistent least-privilege pattern across the Azure template READMEs:

- Provisioning workflows: `Contributor` + `User Access Administrator` at the target resource group or subscription scope.
- Terraform backend access: `Storage Blob Data Contributor` on the backend storage account or container.
- Application or operational workflows: `Contributor` at the relevant resource group scope, unless a different workflow-specific data role is required.
- Runtime role assignments required by AKS or Azure-managed data services remain documented where they are workflow-specific and not generalized to the entire template set.

## Rationale

This matches both the actual Terraform role assignments and the security principle in the constitution. A broad `Owner` assignment is a useful fallback for highly permissive environments, but it should be documented as an exception rather than as the default for the entire Azure template collection.

## Implications

- Readme guidance becomes easier to review in pull requests.
- Operators can assign the right Azure roles before workflow execution without over-privileging the service principal.
- The repository remains aligned with least-privilege automation expectations for Azure deployments.