# Feature Specification: Document Minimal Azure RBAC Requirements

**Feature Branch**: `001-document-azure-rbac`

**Created**: 2026-09-11

**Status**: Draft

**Input**: User description: "Implement GitHub issue #302. Requirements: https://github.com/Esri/arcgis-gitops/issues/302"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review deployment prerequisites before provisioning (Priority: P1)
A platform engineer preparing to deploy or update an ArcGIS enterprise environment on Azure needs a clear statement of the minimum Azure RBAC permissions required for each workflow. The engineer must be able to determine the least-privilege access required before the deployment starts, without relying on assumptions about broad subscription ownership.

**Why this priority**: This is the primary business need behind the issue. Broad subscription-level ownership is a high-risk default that creates unnecessary privilege and slows down secure adoption in customer environments.

**Independent Test**: This can be tested by reviewing the workflow documentation and confirming that each Azure workflow clearly lists the minimum role set required for the tasks it performs.

**Acceptance Scenarios**:

1. **Given** a deployment operator is preparing to run an Azure template, **When** they review the workflow documentation, **Then** they can identify the specific RBAC roles required for that workflow.
2. **Given** an Azure workflow requires only a subset of permissions, **When** the operator compares the documentation to the deployment scope, **Then** the documented role set reflects the least privilege needed instead of a blanket subscription Owner requirement.

---

### User Story 2 - Maintain secure, reviewable Azure automation (Priority: P2)
A repository maintainer or reviewer needs workflow documentation that explains the required RBAC levels in a consistent way across all Azure templates. This makes reviews easier and helps teams keep security controls aligned with the current repository guidance.

**Why this priority**: Consistent documentation reduces governance drift and ensures that operators do not inherit outdated permission assumptions when a workflow changes.

**Independent Test**: This can be tested by checking that all relevant Azure workflow READMEs describe the needed roles and their scope in a consistent, reviewable format.

**Acceptance Scenarios**:

1. **Given** a reviewer is auditing the Azure deployment guidance, **When** they inspect a workflow README, **Then** they can see the permission requirements for that workflow in a clear and standardized form.
2. **Given** a workflow performs both deployment and state-management tasks, **When** the documentation is reviewed, **Then** the role requirements identify the relevant scope and any additional roles needed for operational tasks.

---

### Edge Cases

- What happens when a workflow requires different permissions for provisioning versus ongoing administration?
- How does the documentation handle workflows that need storage, identity, networking, or resource-group-level access in addition to deployment access?
- What happens when a workflow can be completed with a narrower role than the default subscription Owner assignment?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST document the minimum Azure RBAC roles required for each Azure workflow in the corresponding workflow documentation.
- **FR-002**: The documentation MUST identify the role requirements for each workflow without requiring operators to infer permissions from implementation files.
- **FR-003**: The documentation MUST distinguish between subscription-scoped and narrower resource-scoped access when relevant to the operations being performed.
- **FR-004**: The documentation MUST describe the minimum permission set needed for deployment, configuration, and any required operational tasks without defaulting to broad Owner access unless it is truly required.
- **FR-005**: The documentation MUST support least-privilege review and approval by clearly documenting which roles are required and which are not.
- **FR-006**: The repository MUST update workflow guidance where the current documentation states a blanket Owner role at subscription scope when a narrower set of permissions is sufficient.
- **FR-007**: The documentation MUST remain understandable to operators, reviewers, and maintainers who need to validate security and deployment readiness before execution.

### Key Entities *(include if feature involves data)*

- **Azure workflow**: A deployment or operational workflow in the repository that requires Azure permissions to execute.
- **RBAC role**: A built-in or custom Azure role that grants a defined set of permissions needed for a specific workflow or task.
- **Deployment scope**: The effective permission boundary for a workflow, such as subscription, resource group, or resource-specific access.
- **Operating principal**: The identity or service principal authorized to run a workflow and perform the required deployment or maintenance actions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every Azure workflow README lists the minimum required RBAC role set needed for that workflow’s execution and maintenance tasks.
- **SC-002**: The repository documentation removes or narrows blanket subscription Owner requirements where a lesser role would satisfy the workflow’s requirements.
- **SC-003**: Operators can determine the required Azure permissions for a workflow without reading infrastructure implementation details or inferring from an unscoped default.
- **SC-004**: Security reviewers can validate that the repository documentation aligns with least-privilege principles before approving deployment workflows.

## Assumptions

- The repository maintains Azure deployment workflows for ArcGIS Enterprise and each workflow may require a different level of Azure access.
- The feature is documentation-focused and does not change the underlying deployment logic unless documentation updates require explicit alignment.
- The current security intent of the repository is to reduce unnecessary privilege and prefer least-privilege role assignment.
- Documentation updates should be kept consistent with the project’s governance requirements for security, verification, and operational safety.
