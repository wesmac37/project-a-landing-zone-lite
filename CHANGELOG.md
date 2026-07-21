# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned

- Bicep/ARM template parity companion
- Management group / multi-subscription support
- Azure Monitor diagnostic settings integration

## [1.0.0] - 2026-07-21

### Added

- Initial release of the LandingZoneLite PowerShell module (`src/LandingZoneLite`) with public
  functions: `New-LandingZoneResourceGroup`, `Set-LandingZoneTags`,
  `New-LandingZoneRoleAssignment`, `New-LandingZonePolicyAssignment`, `New-LandingZoneBudget`,
  `New-LandingZoneStorageAccount`, `New-LandingZoneKeyVault`, `New-LandingZoneNetworkSpoke`,
  `Get-LandingZoneStatus`.
- Private helper functions: `Write-LzLog`, `Test-LzNameLength`, `ConvertTo-LzTagHashtable`,
  `Get-LzUniqueSuffix`, `Test-LzResourceGroupExists`.
- `scripts/deploy.ps1`, `scripts/validate.ps1`, `scripts/cleanup.ps1` orchestration scripts, all
  supporting `-WhatIf` and fully idempotent.
- `config/landingzone.config.json` sample configuration with documented placeholders.
- Mock-based Pester v5 test suite (`tests/LandingZoneLite.Module.Tests.ps1`,
  `tests/deploy.Tests.ps1`) — no live Azure calls.
- GitHub Actions CI workflow (`.github/workflows/powershell-ci.yml`) running PSScriptAnalyzer and
  Pester with NUnit XML artifact upload.
- Documentation set: architecture (with Mermaid diagrams), demo guide, employer-value narrative,
  validation checklist, troubleshooting guide.
- Sample validation report (`samples/sample-validation-report.md`).

[Unreleased]: https://github.com/example/project-a-landing-zone-lite/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/example/project-a-landing-zone-lite/releases/tag/v1.0.0
