# What This Proves to an Employer

LandingZoneLite is a deliberately small project, but every piece of it maps to a real skill an
enterprise cloud, platform, or DevOps team needs.

## CAF landing zone thinking

- Resource groups segmented by function (management, data, network) — the same segmentation
  principle used at subscription scale in Microsoft's Cloud Adoption Framework.
- A documented, opinionated tagging taxonomy (`Environment`, `Project`, `Owner`, `CostCenter`,
  `ManagedBy`, `DeployDate`) applied consistently across every resource.
- An RBAC pattern (role assignment at resource-group scope) that mirrors how access is delegated
  in real landing zones, without requiring elevated tenant permissions to demo.

## Governance-as-code

- A real Azure Policy assignment (`Inherit a tag from the resource group if missing`, built-in
  definition ID `611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f`) deployed and verified programmatically —
  not just described in a slide deck.
- `validate.ps1` acts as a policy/compliance gate: it checks tag presence, TLS/security settings,
  RBAC mode, and policy assignment existence, and returns a non-zero exit code on failure so it
  can be wired into a pipeline.

## Idempotent automation

- Every resource-creation function in `src/LandingZoneLite/Public` follows a check-then-create
  pattern and supports `-WhatIf`/`-Confirm` — the same discipline expected of Terraform or Bicep,
  implemented in imperative PowerShell to demonstrate first-principles understanding of what
  "idempotent" actually requires at the API-call level.
- `cleanup.ps1` is equally idempotent: it can be run against a fully-deployed, partially-deployed,
  or already-clean environment without erroring.

## Cost discipline

- Every component is explicitly classified in `README.md` as Free / 12-months-free / low-cost
  pay-as-you-go / optional-may-cost-money, grounded in actual Azure Free Account terms.
- The one component that could meaningfully grow resource count (the spoke network) is off by
  default and clearly flagged — showing judgment about blast radius, not just "can it be
  automated."
- A $5/month consumption budget with an 80% alert threshold is deployed by default, because
  budgets and alerts are themselves a free feature with no reason to skip.

## Testing discipline

- A real Pester v5 suite with mock-based unit tests — no live Azure calls, no dependency on a
  real subscription to run CI.
- Tests assert not just "it doesn't throw" but specific behavior: idempotency (a second call
  makes zero additional API calls), and correct parameters passed to Azure cmdlets via
  `Should -Invoke -ParameterFilter`.
- A GitHub Actions workflow runs static analysis (PSScriptAnalyzer, failing on Error severity) and
  the full test suite with NUnit XML output on every push/PR — the same CI shape used in
  production PowerShell module repositories.

## Communication and documentation

- Architecture documented with Mermaid diagrams, not just prose.
- A validation checklist and troubleshooting guide written for someone who has never seen the
  repository before.
- A sample validation report showing exactly what "success" looks like before anyone runs the
  tool.

## Skills demonstrated (summary)

- Azure Resource Manager automation via the Az PowerShell module
- Azure governance: tagging policy, RBAC, Azure Policy assignment
- Azure Cost Management: consumption budgets and alerting
- PowerShell module authorship (manifest, public/private function separation, comment-based help)
- Idempotent infrastructure automation patterns
- Pester v5 mock-based unit testing
- GitHub Actions CI for PowerShell (PSScriptAnalyzer + Pester + artifact publishing)
- Technical writing: architecture diagrams, runbooks, troubleshooting guides
