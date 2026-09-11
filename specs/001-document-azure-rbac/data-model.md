# Data model: Azure workflow RBAC requirements

The feature primarily documents policy metadata, not application data. The model is therefore a lightweight catalog of workflow-level authorization facts.

## Entities

### Workflow

Represents a GitHub Actions workflow or operational task in the Azure templates.

Attributes:

- name: workflow or task name
- family: core, base Linux, base Windows, Kubernetes, Notebook Server
- operation type: image build, infrastructure provisioning, application configuration, backup, restore, destroy
- target scope: subscription, resource group, storage account, key vault, AKS cluster

### RBAC Role

Represents an Azure role that the service principal or identity must hold.

Attributes:

- role name: e.g., `Contributor`, `User Access Administrator`, `Storage Blob Data Owner`
- scope: resource group, subscription, storage account, key vault, namespace
- purpose: resource management, role assignment, data access, or operator-side setup

### Principal

Represents the identity performing the workflow.

Attributes:

- type: service principal, managed identity, cluster user, workflow executor
- scope: same as the workflow target or delegated resource access

## Relationship summary

Each workflow requires one or more RBAC roles for its principal and, in some cases, additional data-plane roles for the underlying storage or secret resources it manages.

## Example catalog entry

| Workflow family | Operation | Required Azure roles | Scope |
| --- | --- | --- | --- |
| Core Azure | Provision shared enterprise resources | `Contributor`, `User Access Administrator` | Resource group or subscription |
| Base Linux/Windows | Create deployment infrastructure | `Contributor`, `User Access Administrator` | Resource group or subscription |
| Base Linux/Windows | Backend state storage | `Storage Blob Data Owner` | Storage account or container |
| Application workflows | Configure deployment | `Contributor` | Deployment resource group |

This catalog is intentionally compact so that reviewers can validate each workflow without reading Terraform implementation details.