# Architecture

## Overview

LandingZoneLite deploys a small, cost-aware foundation that mirrors the core structural ideas of
Microsoft's [Cloud Adoption Framework (CAF) landing zones](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) —
resource group segmentation by function, consistent tagging, an RBAC pattern, policy-driven
governance, and cost guardrails — scaled down so it can be deployed safely and repeatedly inside
an Azure Free Account.

The design intentionally separates **management**, **data**, and **network** concerns into
distinct resource groups, the same segmentation principle used in full-scale landing zones (where
these might instead be entire subscriptions). Everything optional and resource-count-growing
(the spoke network) is off by default; everything free or near-free (tags, policy, budget) is on
by default.

## Component diagram

```mermaid
flowchart TB
    subgraph Subscription["Azure Subscription (Free Account)"]
        subgraph MgmtRG["rg-lzlite-mgmt-eastus"]
            Policy["Policy Assignment:\nInherit tag from RG\n(611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f)"]
            RBAC1["RBAC: Reader role\n(placeholder principal)"]
        end

        subgraph DataRG["rg-lzlite-data-eastus"]
            Storage["Storage Account\nstlzlite<suffix>\nStandard_LRS, TLS1.2, secure transfer\nContainers: bootstrap-logs, artifacts"]
            KeyVault["Key Vault\nkv-lzlite-<suffix>\nRBAC auth, soft-delete\nSecret: SampleAppSetting"]
            RBAC2["RBAC: Reader role\n(placeholder principal)"]
        end

        subgraph NetworkRG["rg-lzlite-network-eastus (optional, -IncludeNetwork)"]
            VNet["VNet vnet-lzlite-spoke-eastus\n10.30.0.0/16"]
            Subnet["Subnet snet-workload\n10.30.0.0/24"]
            NSG["NSG nsg-lzlite-workload"]
            VNet --> Subnet
            NSG --> Subnet
        end

        Budget["Consumption Budget\nbudget-lzlite-monthly\n$5/month, 80% alert\n(optional, -IncludeBudget, default ON)"]
    end

    HubFuture["Future hub VNet\n(not deployed by this tool)"] -. future peering .-> VNet

    Subscription --> Budget

    classDef optional stroke-dasharray: 5 5;
    class NetworkRG optional;
    class Budget optional;
```

## Deployment flow

```mermaid
sequenceDiagram
    participant User
    participant deploy.ps1
    participant Module as LandingZoneLite module
    participant Azure as Azure Resource Manager

    User->>deploy.ps1: ./deploy.ps1 [-IncludeNetwork] [-WhatIf]
    deploy.ps1->>deploy.ps1: Load config/landingzone.config.json
    deploy.ps1->>Azure: Get-AzContext
    Azure-->>deploy.ps1: active subscription context
    deploy.ps1->>Azure: Register-AzResourceProvider (Storage, KeyVault, Network, Consumption, Authorization, PolicyInsights)
    deploy.ps1->>Module: New-LandingZoneResourceGroup (mgmt, data, [network])
    Module->>Azure: Get-AzResourceGroup / New-AzResourceGroup
    deploy.ps1->>Module: New-LandingZoneRoleAssignment (Reader, continue-on-error)
    Module->>Azure: New-AzRoleAssignment
    deploy.ps1->>Module: New-LandingZonePolicyAssignment (tag inheritance)
    Module->>Azure: New-AzPolicyAssignment
    deploy.ps1->>Module: New-LandingZoneBudget (optional, default ON)
    Module->>Azure: New-AzConsumptionBudget
    deploy.ps1->>Module: New-LandingZoneStorageAccount
    Module->>Azure: New-AzStorageAccount + New-AzStorageContainer
    deploy.ps1->>Module: New-LandingZoneKeyVault
    Module->>Azure: New-AzKeyVault + Set-AzKeyVaultSecret
    deploy.ps1->>Module: New-LandingZoneNetworkSpoke (optional)
    Module->>Azure: New-AzVirtualNetwork + New-AzNetworkSecurityGroup
    deploy.ps1->>User: Summary table + ../logs/deploy-<timestamp>.log
```

## Resource groups

| Resource Group | Purpose | Created by default? |
|---|---|---|
| `rg-lzlite-mgmt-eastus` | Governance surface: policy assignment, RBAC pattern | Yes |
| `rg-lzlite-data-eastus` | Storage account, Key Vault | Yes |
| `rg-lzlite-network-eastus` | Spoke VNet, subnet, NSG | No — only with `-IncludeNetwork` |

## Tagging strategy

Every resource group and resource receives the same standard tag set, applied via
`ConvertTo-LzTagHashtable` (private helper) and `Set-LandingZoneTags` (public function):

| Tag | Example value | Purpose |
|---|---|---|
| `Environment` | `sandbox` | Environment classification; also the tag enforced by the policy assignment |
| `Project` | `LandingZoneLite` | Fixed value identifying resources owned by this toolkit |
| `Owner` | `your-name@example.com` | Traceability to a human owner |
| `CostCenter` | `CC-0000` | Cost allocation |
| `ManagedBy` | `PowerShell` | Signals automation-managed, not manually created |
| `DeployDate` | `2026-07-21` | ISO date stamp at deploy time |

## Governance-as-code

The policy assignment uses Azure's built-in **"Inherit a tag from the resource group if missing"**
definition (ID `611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f`), assigned at the `rg-lzlite-mgmt-eastus`
scope with `tagName = Environment`. This means any resource created in scope without an
`Environment` tag automatically inherits it from its resource group — a lightweight, non-blocking
governance guardrail appropriate for a "lite" landing zone (the deprecated "Require a tag on
resources" definition is intentionally not used).

## Idempotency model

Every `New-LandingZone*` function in `src/LandingZoneLite/Public` follows the same
check-then-create pattern: query for the resource by name/scope, return the existing object
unchanged if found, otherwise create it. Combined with `SupportsShouldProcess` (`-WhatIf`/
`-Confirm`), this makes `deploy.ps1` safe to re-run against a partially-deployed or fully-deployed
environment without duplicating resources or failing on "already exists" errors.
