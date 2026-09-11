# Tasks: Document Minimal Azure RBAC Requirements

**Input**: Design documents from `/specs/001-document-azure-rbac/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Tests are optional for this documentation-only feature. Validation is performed by reviewing README guidance and checking Azure role wording against the repo’s least-privilege guidance.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Documentation Review)

**Purpose**: Confirm the repository governance and review the current Azure RBAC guidance to be updated.

- [X] T001 Review the repository constitution and issue requirements in [.specify/memory/constitution.md](../../.specify/memory/constitution.md) and [specs/001-document-azure-rbac/spec.md](spec.md) to confirm least-privilege and reviewability constraints
- [X] T002 [P] Inventory the Azure workflow READMEs that still use subscription-wide Owner wording and list the affected files in [azure/README.md](../../azure/README.md), [azure/arcgis-enterprise-core/README.md](../../azure/arcgis-enterprise-core/README.md), [azure/arcgis-enterprise-base-linux/README.md](../../azure/arcgis-enterprise-base-linux/README.md), [azure/arcgis-enterprise-base-windows/README.md](../../azure/arcgis-enterprise-base-windows/README.md), and [azure/arcgis-notebook-server-linux/README.md](../../azure/arcgis-notebook-server-linux/README.md)

---

## Phase 2: Foundational (RBAC Mapping and Scope Validation)

**Purpose**: Establish the minimum role sets and scope boundaries before editing workflow docs.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 Validate the actual Azure role assignments used by the Terraform implementation in [azure/arcgis-enterprise-core/infrastructure-core/main.tf](../../azure/arcgis-enterprise-core/infrastructure-core/main.tf) and [azure/arcgis-enterprise-base-windows/infrastructure/main.tf](../../azure/arcgis-enterprise-base-windows/infrastructure/main.tf) to confirm the least-privilege pattern for provisioning and storage access
- [X] T004 [P] Map each workflow family to its required roles and scopes using the decisions captured in [specs/001-document-azure-rbac/research.md](research.md) and [specs/001-document-azure-rbac/data-model.md](data-model.md)
- [X] T005 [P] Confirm the final wording pattern for each workflow section: `Contributor` for management operations, `User Access Administrator` only where Terraform creates role assignments, and `Storage Blob Data Contributor` on the Terraform state storage account where applicable

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel.

---

## Phase 3: User Story 1 - Review deployment prerequisites before provisioning (Priority: P1) 🎯 MVP

**Goal**: Ensure each Azure workflow README clearly states the minimum RBAC roles required before provisioning or configuration work begins.

**Independent Test**: Review each workflow README and confirm its permission list matches the action the workflow performs without reverting to a broad subscription Owner default.

### Implementation for User Story 1

- [X] T006 [P] [US1] Update the shared Azure guidance in [azure/README.md](../../azure/README.md) to explain the least-privilege pattern for provisioning, backend state access, and workflow-specific resource-scoped RBAC
- [X] T007 [P] [US1] Update the core workflow guidance in [azure/arcgis-enterprise-core/README.md](../../azure/arcgis-enterprise-core/README.md) so each provisioning and destroy section lists the minimum role set without blanket subscription Owner wording
- [X] T008 [P] [US1] Update the Linux deployment guidance in [azure/arcgis-enterprise-base-linux/README.md](../../azure/arcgis-enterprise-base-linux/README.md) to document `Contributor` + `User Access Administrator` and the required `Storage Blob Data Owner` state-storage access in the infrastructure and application workflows
- [X] T009 [P] [US1] Update the Windows deployment guidance in [azure/arcgis-enterprise-base-windows/README.md](../../azure/arcgis-enterprise-base-windows/README.md) so build, infrastructure, and destroy workflows specify the least-privilege roles and resource scope
- [X] T010 [US1] Update the Notebook Server guidance in [azure/arcgis-notebook-server-linux/README.md](../../azure/arcgis-notebook-server-linux/README.md) so image build, infrastructure, and destroy workflows state the correct workflow-specific role minimum instead of a subscription-scope Owner default

**Checkpoint**: At this point, User Story 1 should be fully functional and independently reviewable before deployment.

---

## Phase 4: User Story 2 - Maintain secure, reviewable Azure automation (Priority: P2)

**Goal**: Keep the Azure template docs consistent, reviewable, and aligned with the repository’s least-privilege governance.

**Independent Test**: Inspect the documentation set and confirm the RBAC language is consistent across all workflow READMEs and review guidance.

### Implementation for User Story 2

- [X] T011 [P] [US2] Normalize the wording and scope notes across the Azure template READMEs so the documentation consistently distinguishes management-plane permissions from data-plane access in [azure/README.md](../../azure/README.md), [azure/arcgis-enterprise-core/README.md](../../azure/arcgis-enterprise-core/README.md), [azure/arcgis-enterprise-base-linux/README.md](../../azure/arcgis-enterprise-base-linux/README.md), [azure/arcgis-enterprise-base-windows/README.md](../../azure/arcgis-enterprise-base-windows/README.md), and [azure/arcgis-notebook-server-linux/README.md](../../azure/arcgis-notebook-server-linux/README.md)
- [X] T012 [P] [US2] Review the acceptance checklist in [specs/001-document-azure-rbac/quickstart.md](quickstart.md) and verify each rule is satisfied by the updated workflow documentation
- [X] T013 [US2] Search the repository for stale `Owner` wording and confirm the remaining Azure workflow documentation reflects the least-privilege model rather than blanket subscription Owner access

**Checkpoint**: At this point, User Stories 1 and 2 should both be independently reviewable and ready for approval.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, doc consistency, and issue closure readiness.

- [X] T014 [P] Confirm the final documentation explains the minimum role set and the role scope in a format operators and reviewers can validate quickly in [specs/001-document-azure-rbac/research.md](research.md) and [specs/001-document-azure-rbac/quickstart.md](quickstart.md)
- [X] T015 [P] Run a final repository grep to ensure no Azure workflow README still uses blanket subscription `Owner` guidance where a narrower, least-privilege role set is sufficient
- [X] T016 Finalize the issue-ready documentation and summary in [specs/001-document-azure-rbac/tasks.md](tasks.md) so the work is ready for review and merge

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - blocks all user story work
- **User Story 1 (Phase 3)**: Depends on Foundational completion and can proceed independently
- **User Story 2 (Phase 4)**: Depends on Foundational completion and can proceed independently after US1 validation
- **Polish (Phase 5)**: Depends on both user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational and does not depend on User Story 2
- **User Story 2 (P2)**: Can start after Foundational and can be reviewed independently of US1

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel.
- Foundational tasks T003, T004, and T005 can run in parallel after the governance review.
- User Story 1 tasks T006 through T010 can be worked in parallel by different README sections if needed.
- User Story 2 tasks T011 through T013 can be worked in parallel during the final review pass.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. Validate that the Azure workflow documentation clearly states the least-privilege role set before provisioning

### Incremental Delivery

- Phase 3 delivers the core RBAC documentation fix for all Azure workflow README sections.
- Phase 4 standardizes the wording and confirms the documentation remains reviewable and governance-compliant.
- Phase 5 performs final validation and issue readiness checks for the merge review.
