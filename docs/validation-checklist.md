# Validation Checklist

Use this checklist to manually confirm a deployment before considering it "done," or as a
reference for what `scripts/validate.ps1` checks automatically.

## Before you deploy

- [ ] `config/landingzone.config.json` `subscriptionId` replaced with your real subscription ID
- [ ] `config/landingzone.config.json` `ownerTag` replaced with your name/email
- [ ] `config/landingzone.config.json` `uniqueSuffix` replaced with a freshly generated 6-character
      lowercase suffix
- [ ] `config/landingzone.config.json` `rbacPrincipalObjectId` replaced with a real object ID from
      your tenant, or intentionally left as the placeholder (RBAC step will log a warning and
      continue — this is expected and non-fatal)
- [ ] `config/landingzone.config.json` `contactEmail` replaced with a real address if you want
      budget alerts to reach you
- [ ] Logged in with `Connect-AzAccount` and confirmed the correct subscription with
      `Get-AzContext`

## Resource groups

- [ ] `rg-lzlite-mgmt-eastus` exists
- [ ] `rg-lzlite-data-eastus` exists
- [ ] `rg-lzlite-network-eastus` exists **only if** you deployed with `-IncludeNetwork`
- [ ] Every resource group has all six standard tags: `Environment`, `Project`, `Owner`,
      `CostCenter`, `ManagedBy`, `DeployDate`

## RBAC

- [ ] Reader role assignment attempted at `rg-lzlite-mgmt-eastus` and `rg-lzlite-data-eastus`
      scope (check `../logs/deploy-<timestamp>.log` — a warning here is expected if you left the
      placeholder object ID in place)

## Policy

- [ ] Policy assignment `inherit-tag-lzlite` exists at `rg-lzlite-mgmt-eastus` scope
- [ ] Policy definition ID is `/providers/Microsoft.Authorization/policyDefinitions/611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f`
- [ ] Policy parameter `tagName` is set to `Environment`

## Budget

- [ ] If deployed with budgets enabled (default): `budget-lzlite-monthly` exists with amount `$5`
      (or your configured `budgetAmountUSD`)
- [ ] If you explicitly disabled budgets: confirm no budget was created

## Storage account

- [ ] Storage account `stlzlite<uniqueSuffix>` exists in `rg-lzlite-data-eastus`
- [ ] SKU is `Standard_LRS`
- [ ] `EnableHttpsTrafficOnly` (secure transfer) is `true`
- [ ] `MinimumTlsVersion` is `TLS1_2`
- [ ] `AllowBlobPublicAccess` is `false`
- [ ] Containers `bootstrap-logs` and `artifacts` both exist

## Key Vault

- [ ] Key Vault `kv-lzlite-<uniqueSuffix>` exists in `rg-lzlite-data-eastus`
- [ ] `EnableRbacAuthorization` is `true`
- [ ] Soft-delete is enabled
- [ ] Secret `SampleAppSetting` exists

## Network (only if `-IncludeNetwork` was used)

- [ ] VNet `vnet-lzlite-spoke-eastus` exists with address space `10.30.0.0/16`
- [ ] Subnet `snet-workload` exists with address prefix `10.30.0.0/24`
- [ ] NSG `nsg-lzlite-workload` exists and is associated with the subnet

## Running the automated check

```powershell
./scripts/validate.ps1               # plain deployment
./scripts/validate.ps1 -IncludeNetwork  # if you deployed with -IncludeNetwork
```

Expect a PASS/FAIL markdown table on the console and a copy written to
`../logs/validation-report-<timestamp>.md`. See `samples/sample-validation-report.md` for a
realistic example of the expected output. Exit code `0` means every check passed; exit code `1`
means at least one check failed.
