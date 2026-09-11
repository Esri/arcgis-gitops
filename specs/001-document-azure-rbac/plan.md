# Implementation Plan: Document Minimal Azure RBAC Requirements

**Branch**: `001-document-azure-rbac` | **Date**: 2026-09-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-document-azure-rbac/spec.md`

## Summary
This feature updates the Azure deployment guidance so each workflow documents the minimum RBAC requirements needed to execute it, rather than defaulting to a broad subscription-scope Owner assignment.
## Technical Context

**Language/Version**: Documentation only (Markdown / GitHub Actions workflow guidance)

**Primary Dependencies**: GitHub Actions, Azure CLI, Terraform, Packer, Azure Key Vault, Azure Storage, AKS, Application Gateway
**Storage**: Azure Storage accounts, Key Vault secrets, Terraform state backend, Cosmos DB and Service Bus for HA deployment patterns

**Testing**: Repository documentation review; grep validation for plain-language RBAC guidance and README consistency

**Target Platform**: Azure subscription / resource-group-scoped workflow automation
**Project Type**: infrastructure automation documentation

**Performance Goals**: Not performance sensitive; prioritize clear reviewability and least-privilege security guidance

**Constraints**: The documentation must avoid blanket Owner assignment unless the workflow truly requires it, remain reviewable for platform engineers, and align with source-controlled Terraform definitions that assign identity permissions to storage, vaults, and managed identities.
**Scale/Scope**: Azure README guidance for the core, Linux, Windows, and Notebook Server deployment templates and the shared Azure template instructions.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*
Pass. This change directly enforces the repository constitution’s Security and Least-Privilege Automation principle and the requirement for repeatable, reviewable delivery. The update does not alter deployment logic; it clarifies the authorization boundary and expected permissions for each workflow in a way that is easier to review and approve.

## Project Structure

### Documentation (this feature)
```text
specs/001-document-azure-rbac/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── spec.md
└── checklists/
  └── requirements.md
```

### Source Code (repository root)

```text
azure/
├── README.md
├── arcgis-enterprise-core/
│   └── README.md
├── arcgis-enterprise-base-linux/
│   └── README.md
├── arcgis-enterprise-base-windows/
│   └── README.md
├── arcgis-enterprise-k8s/
│   └── README.md
└── arcgis-notebook-server-linux/
  └── README.md
```

**Structure Decision**: This feature is documentation-only and scope is limited to the Azure template READMEs plus the feature planning artifacts in the spec directory.

## Complexity Tracking

No constitution violations require justification. This work remains within the repository’s documented governance model and does not introduce additional systems or architectural complexity.
# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]

**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]

**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]

**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]

**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]

**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]

**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]

**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

[Gates determined based on constitution file]

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
