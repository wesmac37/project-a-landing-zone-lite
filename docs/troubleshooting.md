# Troubleshooting

## "No active Az context found" when running deploy.ps1

You haven't authenticated yet in this PowerShell session. Run:

```powershell
Connect-AzAccount
# In Cloud Shell or a headless session:
Connect-AzAccount -UseDeviceAuthentication
```

Then confirm with `Get-AzContext` that the correct subscription is selected. If it isn't:

```powershell
Set-AzContext -SubscriptionId '<your-subscription-id>'
```

## RBAC role assignment step logs a warning and continues

This is expected behavior, not a bug. `New-LandingZoneRoleAssignment` wraps
`New-AzRoleAssignment` in try/catch and treats failures as non-fatal, because the default
`rbacPrincipalObjectId` in `config/landingzone.config.json` is a placeholder GUID that does not
exist in your Azure AD tenant. To make this step succeed, replace `rbacPrincipalObjectId` with a
real user, group, or service principal object ID from your tenant (find one with
`Get-AzADUser -SearchString 'you@example.com'` or `Get-AzADGroup -SearchString 'your-group'`).

## "The storage account named 'stlzliteXXXXXX' is already taken"

Storage account names are globally unique across all of Azure, not just your subscription. Generate
a new `uniqueSuffix` in `config/landingzone.config.json`:

```powershell
-join ((97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})
```

and re-run `deploy.ps1`. The Key Vault name uses the same suffix and has the same global
uniqueness requirement.

## Policy assignment fails with "PolicyDefinitionNotFound"

This means the built-in policy definition ID
(`611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f`, "Inherit a tag from the resource group if missing") is
not visible at the scope you're querying. Confirm you're logged into the correct tenant and that
`Get-AzPolicyDefinition -Id '/providers/Microsoft.Authorization/policyDefinitions/611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f'`
returns a result before re-running `deploy.ps1`.

## Budget creation fails with a permissions error

`New-AzConsumptionBudget` requires Cost Management Contributor (or a similarly privileged role) at
subscription scope. Free/Trial subscriptions where you are the Account Administrator normally have
this by default. If you're operating in a subscription you don't own, ask the subscription owner
to grant you `Cost Management Contributor`, or run `deploy.ps1` without budgets:

```powershell
./scripts/deploy.ps1 -IncludeBudget:$false
```

## Resource provider registration is slow or times out

`Register-AzResourceProvider` is asynchronous — registration can take a few minutes the first time
a provider is used in a subscription. Re-run `deploy.ps1`; already-registered providers are
detected and skipped, so re-running is safe and idempotent.

## validate.ps1 reports FAIL for a component you didn't deploy

Pass the same switches to `validate.ps1` that you used with `deploy.ps1`. For example, if you
deployed with `-IncludeNetwork`, validate with:

```powershell
./scripts/validate.ps1 -IncludeNetwork
```

Without the switch, network checks default to `Skipped` (not evaluated), and unexpected network
resources found without the switch will still be reported accurately based on what's live in the
subscription.

## cleanup.ps1 doesn't remove everything in one pass

This can happen if Azure is still processing a dependent deletion (for example, a storage account
delete that hasn't fully propagated before the resource group delete is attempted). Re-run
`cleanup.ps1` — it's fully idempotent and will simply report "not found" for anything already
removed, and retry anything still present.

## Key Vault name conflicts after deleting it

By default, `Remove-AzKeyVault` only soft-deletes the vault; the name remains reserved for the
soft-delete retention period (7 days per `SoftDeleteRetentionInDays` in
`New-LandingZoneKeyVault`). If you need to reuse the exact same name immediately, purge it:

```powershell
./scripts/cleanup.ps1 -Force -PurgeKeyVault
```

## PSScriptAnalyzer or Pester fails in CI but passes locally

Ensure your local PSScriptAnalyzer and Pester module versions match what the workflow installs
(see `.github/workflows/powershell-ci.yml`). Run:

```powershell
Get-Module -Name PSScriptAnalyzer, Pester -ListAvailable
```

and update with `Install-Module -Name Pester -MinimumVersion 5.5.0 -Force -SkipPublisherCheck` if
your local version is older than v5.
