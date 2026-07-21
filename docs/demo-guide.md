# How to Demo This Project

A script for walking a hiring manager, interviewer, or teammate through LandingZoneLite in about
10 minutes.

## 1. Set the scene (1 minute)

> "This is a landing-zone bootstrap tool I built in PowerShell. It mirrors the same governance
> patterns Microsoft's Cloud Adoption Framework recommends for onboarding a new environment or
> workload — resource group segmentation, consistent tagging, an RBAC pattern, policy-as-code, and
> cost guardrails — scaled down so it's safe to run on a free Azure account."

Open `README.md` and point to the architecture diagram and the cost notes table.

## 2. Show the code structure (2 minutes)

```
src/LandingZoneLite/
├── Public/   <- one function per landing-zone capability
└── Private/  <- logging, validation, tagging helpers
scripts/      <- deploy.ps1, validate.ps1, cleanup.ps1 orchestrate the module
tests/        <- Pester v5, fully mocked, no live Azure calls
```

Call out that every `New-LandingZone*` function is idempotent (check-then-create) and supports
`-WhatIf`, and that `Get-LandingZoneStatus` is a pure read-only reporting function used by
`validate.ps1`.

## 3. Run a dry-run deploy (2 minutes)

```powershell
cd project-a-landing-zone-lite
./scripts/deploy.ps1 -WhatIf
```

Narrate the output: it walks through resource groups, RBAC, policy assignment, budget, storage
account, Key Vault, and (if `-IncludeNetwork` is passed) the spoke network — without making any
changes. This is the safest way to demo against a real subscription.

## 4. Run the Pester test suite (2 minutes)

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -Force -SkipPublisherCheck
Invoke-Pester -Path ./tests -Output Detailed
```

Point out that the tests mock every `Az*` cmdlet — none of them touch a real subscription — and
that they assert idempotency (`Should -Invoke ... -Times 0` on the second call) and correct
parameters passed to Azure cmdlets (`Should -Invoke ... -ParameterFilter`).

## 5. Walk through validate.ps1 output (2 minutes)

Open `samples/sample-validation-report.md` and explain that this is what `validate.ps1` produces
after a real deployment: a PASS/FAIL table per component, with a non-zero exit code on any
failure — making it usable as a CI/CD gate, not just a manual check.

## 6. Close with the CI workflow (1 minute)

Open `.github/workflows/powershell-ci.yml` and show that every push/PR runs PSScriptAnalyzer
(failing the build on Error-severity findings) and the full Pester suite with NUnit XML results
published as a build artifact — the same quality gate pattern used in production PowerShell
repositories.

## Optional: live deployment (if you have a spare free-tier subscription)

```powershell
# 1. Edit config/landingzone.config.json: subscriptionId, ownerTag, uniqueSuffix
# 2. Connect
Connect-AzAccount
# 3. Deploy (no network, budget on by default)
./scripts/deploy.ps1
# 4. Validate
./scripts/validate.ps1
# 5. Clean up
./scripts/cleanup.ps1 -Force
```

Total resource footprint for a plain run: 2 resource groups, 1 storage account, 1 Key Vault, 1
policy assignment, 1 budget — all free-tier or low-cost pay-as-you-go (see the cost table in
`README.md`).
