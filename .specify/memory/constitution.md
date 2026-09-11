# ArcGIS GitOps Constitution
<!-- Sync Impact Report
Version change: 0.0.0 -> 1.0.0
Modified principles: N/A (initial constitution)
Added sections: Core Principles, Security & Compliance, Delivery Workflow, Governance
Removed sections: template placeholders and example content
Follow-up TODOs: None
-->

## Core Principles

### I. Infrastructure as Code by Default
This repository must treat infrastructure, configuration, and operational workflows as version-controlled artifacts. Every environment change must originate in declarative definitions under aws/, azure/, config/, and related automation paths, and it must be reviewable through pull requests before execution. Changes that bypass infrastructure-as-code patterns, hide environment state in ad hoc scripts, or embed secrets in source files are non-compliant.

### II. Security and Least-Privilege Automation
All automation must enforce least privilege, secure defaults, and explicit authorization boundaries. Secrets must never be committed to the repository; credentials must come from approved secret stores or CI/CD environment variables. IAM policies, network controls, certificates, and operational access must be reviewed and approved before deployment. Any workflow that broadens permissions, weakens isolation, or creates untracked trust boundaries requires a documented exception and owner approval.

### III. Verification Before Deployment
Changes must be validated with the smallest relevant checks before promotion. For infrastructure, configuration, and automation, the team must validate syntax, plan outputs, and expected state changes. For operational procedures, smoke tests, dry-runs, or recovery checks are required whenever they reduce deployment risk. Deployment without evidence of validation is a governance violation.

### IV. Repeatable, Reviewable Delivery
The repository exists to standardize repeatable delivery across environments. Workflows must be modular, idempotent, and documented so operators can reproduce a deployment or recovery action. Changes to templates, modules, or deployment logic require clear documentation, compatibility review, and evidence that existing environment patterns remain intact.

### V. Operational Safety and Recovery
Automation must be designed to support safe rollback, disaster recovery, and auditing. Any environment change must preserve recoverability, backup, restoration, and monitoring requirements. Production changes require explicit review of blast radius, rollback steps, and impact on existing enterprise systems. If an operation cannot be rolled back safely, it must not proceed without written approval and a risk acceptance record.

## Security & Compliance
This repository governs enterprise deployments of ArcGIS Enterprise on AWS and Azure. All templates and automation logic must align with enterprise security requirements, network segmentation, least-privilege access, certificate handling, and compliance controls defined by the owning organization. Authentication and authorization must use managed identities, secure secret stores, and approved policy definitions instead of embedded credentials or unmanaged local state.

## Delivery Workflow
All work in this repository follows a documented change path: define the desired state in source-controlled templates, review architecture and security implications, validate with the relevant checks, and apply changes through approved automation workflows. Pull requests must communicate the exact platform, target environment, scope, and rollback plan. Changes with operational risk must include supervised approval and a tested recovery path before execution.

## Governance
This Constitution supersedes ad hoc deployment practices for this repository. Any amendment must be documented in the project constitution, reviewed for operational impact, and approved by the responsible maintainers before it is enforced. Changes to governance must be traceable to a written rationale and must not remove required controls without a migration plan.

Versioning follows semantic versioning. MAJOR changes are backward-incompatible changes to governance or principle definitions; MINOR changes add a principle or materially expand governance guidance; PATCH changes are clarifications, wording improvements, or non-semantic refinements. All project changes must align with the repository’s version-controlled automation patterns, security controls, and review requirements.

Compliance review is mandatory for changes that affect deployment safety, authorization, or operational standards. Reviewers must confirm that the change remains consistent with security, reliability, and recovery obligations before approval. The project maintains a single source of truth for operational governance in this document and the supporting documentation under the repository’s workflow, automation, and configuration artifacts.

**Version**: 1.0.0 | **Ratified**: 2026-09-10 | **Last Amended**: 2026-09-10
