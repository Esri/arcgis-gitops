# Repository Governance & Standards

## Infrastructure as Code by Default

This repository must treat infrastructure, configuration, and operational workflows as version-controlled artifacts. Every environment change must originate in declarative definitions under aws/, azure/, config/, and related automation paths, and it must be reviewable through pull requests before execution. Changes that bypass infrastructure-as-code patterns, hide environment state in ad hoc scripts, or embed secrets in source files are non-compliant.

## Security and Least-Privilege Automation

All automation must enforce least privilege, secure defaults, and explicit authorization boundaries. Secrets must never be committed to the repository; credentials must come from approved secret stores or CI/CD environment variables. IAM policies, network controls, certificates, and operational access must be reviewed and approved before deployment. Any workflow that broadens permissions, weakens isolation, or creates untracked trust boundaries requires a documented exception and owner approval.

## Repeatable, Reviewable Delivery

The repository exists to standardize repeatable delivery across environments. Workflows must be modular, idempotent, and documented so operators can reproduce a deployment or recovery action. Changes to templates, modules, or deployment logic require clear documentation, compatibility review, and evidence that existing environment patterns remain intact.

## Operational Safety and Recovery

Automation must be designed to support safe rollback, disaster recovery, and auditing. Any environment change must preserve recoverability, backup, restoration, and monitoring requirements. Production changes require explicit review of blast radius, rollback steps, and impact on existing enterprise systems. If an operation cannot be rolled back safely, it must not proceed without written approval and a risk acceptance record.

## Delivery Workflow

All work in this repository follows a documented change path: define the desired state in source-controlled templates, review architecture and security implications, validate with the relevant checks, and apply changes through approved automation workflows. Pull requests must communicate the exact platform, target environment, scope, and rollback plan. All changes must be traceable and auditable to ensure accountability and operational safety.

## Documentation and Knowledge Management

All operational procedures, infrastructure definitions, and automation workflows must be thoroughly documented. Documentation should include architecture diagrams, configuration details, recovery procedures, and any exceptions to standard practices. Knowledge must be maintained in a version-controlled manner alongside the code to ensure that all team members have access to the latest operational guidance and historical context. The documentation must be reviewed and updated regularly to reflect changes in the infrastructure, automation, and operational practices.

## Consistency

All templates, modules, and automation workflows must follow consistent patterns, conventions, and styles. This includes naming conventions, directory structures, coding standards, and documentation practices. Consistency ensures that team members can easily understand, review, and maintain the infrastructure and operational code, reducing the risk of errors and improving overall efficiency.

The same versions of libraries, modules, and third-party dependencies must be used consistently across all environments to avoid compatibility issues and ensure predictable behavior.

## Mandatory Copyright & License Headers

- **Rule**: Every new or modified source file (e.g., `.py`, `.tf`, `.hcl`, `.sh`, `.yaml`) MUST include the standard organization copyright header at the very top of the file before any package declarations or logic.

- **Header Template**:

```text
# Copyright 2026 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
```

The copyright year or range of years should reflect the period during which the file was created and any subsequent modifications. For example, if a file was initially created in 2024 and modified in 2026, the header should indicate "2024-2026".
