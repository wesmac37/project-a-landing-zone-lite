#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys the LandingZoneLite Azure foundation: resource groups, tags, RBAC pattern, policy
    assignment, optional budget, storage account, Key Vault, and optional spoke network.

.DESCRIPTION
    Reads settings from a JSON config file, verifies an active Az context, registers required
    resource providers, then calls LandingZoneLite module functions in dependency order:
      1. Resource groups (mgmt, data, and optionally network)
      2. Tags (applied at RG creation time; re-asserted via Set-LandingZoneTags)
      3. RBAC role assignment (continue-on-error by design)
      4. Policy assignment (tag inheritance) at the mgmt RG scope
      5. Consumption budget (optional, default on)
      6. Storage account with bootstrap containers
      7. Key Vault with demo secret
      8. Network spoke (optional, default off)
    Every resource-creation call is idempotent (check-then-create) and supports -WhatIf. A summary
    table is printed at the end, and a timestamped log is written under ../logs/.

.PARAMETER ConfigPath
    Path to the landingzone.config.json file. Defaults to ../config/landingzone.config.json
    relative to this script.

.PARAMETER IncludeNetwork
    Switch to force-enable creation of the spoke-ready network resources, overriding the config
    file's includeNetwork value.

.PARAMETER IncludeBudget
    Switch to force-enable creation of the consumption budget, overriding the config file's
    includeBudget value.

.PARAMETER WhatIf
    Standard PowerShell risk-mitigation switch. Shows what would happen without making changes.

.EXAMPLE
    ./deploy.ps1
    Runs a plain deployment using ../config/landingzone.config.json.

.EXAMPLE
    ./deploy.ps1 -IncludeNetwork
    Runs a deployment that also creates the spoke-ready network resources.

.EXAMPLE
    ./deploy.ps1 -WhatIf
    Dry-run: shows every change that would be made without creating anything.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..' 'config' 'landingzone.config.json'),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNetwork,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeBudget
)

$ErrorActionPreference = 'Stop'

# --- Import the LandingZoneLite module ---
$modulePath = Join-Path $PSScriptRoot '..' 'src' 'LandingZoneLite' 'LandingZoneLite.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

# --- Set up logging ---
$logDirectory = Join-Path $PSScriptRoot '..' 'logs'
if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logDirectory "deploy-$timestamp.log"

Write-LzLog -Message "Starting LandingZoneLite deployment. Log: $logPath" -Level Info -LogPath $logPath

# --- Load config ---
if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found at '$ConfigPath'. Copy config/landingzone.config.json and edit placeholders before running."
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
Write-LzLog -Message "Loaded config from '$ConfigPath'." -Level Info -LogPath $logPath

# CLI switches override config file values.
$effectiveIncludeNetwork = $IncludeNetwork.IsPresent -or [bool]$config.includeNetwork
if ($IncludeNetwork.IsPresent) { $effectiveIncludeNetwork = $true }
$effectiveIncludeBudget = $IncludeBudget.IsPresent -or [bool]$config.includeBudget
if ($PSBoundParameters.ContainsKey('IncludeBudget')) { $effectiveIncludeBudget = $IncludeBudget.IsPresent }

Write-LzLog -Message "Effective settings -> IncludeNetwork: $effectiveIncludeNetwork, IncludeBudget: $effectiveIncludeBudget" -Level Info -LogPath $logPath

# --- Verify Az context ---
$context = Get-AzContext
if (-not $context) {
    throw "No active Az context found. Run Connect-AzAccount (or Connect-AzAccount -UseDeviceAuthentication in Cloud Shell) before running deploy.ps1."
}
Write-LzLog -Message "Using Az context: subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))." -Level Info -LogPath $logPath

if ($config.subscriptionId -and $context.Subscription.Id -ne $config.subscriptionId) {
    Write-LzLog -Message "Warning: current context subscription ($($context.Subscription.Id)) does not match config subscriptionId ($($config.subscriptionId)). Continuing with the active context." -Level Warning -LogPath $logPath
}

# --- Register required resource providers ---
$requiredProviders = @(
    'Microsoft.Storage',
    'Microsoft.KeyVault',
    'Microsoft.Authorization',
    'Microsoft.Consumption',
    'Microsoft.Network',
    'Microsoft.PolicyInsights'
)

foreach ($provider in $requiredProviders) {
    try {
        $registration = Get-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop |
            Select-Object -First 1
        if ($registration -and $registration.RegistrationState -eq 'Registered') {
            Write-LzLog -Message "Resource provider '$provider' already registered." -Level Info -LogPath $logPath
        }
        else {
            if ($PSCmdlet.ShouldProcess($provider, 'Register resource provider')) {
                Write-LzLog -Message "Registering resource provider '$provider'." -Level Info -LogPath $logPath
                Register-AzResourceProvider -ProviderNamespace $provider -ErrorAction Stop | Out-Null
            }
        }
    }
    catch {
        Write-LzLog -Message "Could not register provider '$provider': $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }
}

# --- Build tag set ---
$tags = ConvertTo-LzTagHashtable -Environment $config.environment -Owner $config.ownerTag -CostCenter $config.costCenterTag

# --- Resource group names ---
$mgmtRg    = 'rg-lzlite-mgmt-eastus'
$networkRg = 'rg-lzlite-network-eastus'
$dataRg    = 'rg-lzlite-data-eastus'

$summary = [System.Collections.Generic.List[object]]::new()

function Add-SummaryRow {
    param($Component, $Name, $Result)
    $summary.Add([PSCustomObject]@{ Component = $Component; Name = $Name; Result = $Result })
}

try {
    # 1. Resource groups
    Write-LzLog -Message '--- Step 1: Resource groups ---' -Level Info -LogPath $logPath
    New-LandingZoneResourceGroup -Name $mgmtRg -Location $config.location -Tags $tags -WhatIf:$WhatIfPreference | Out-Null
    Add-SummaryRow 'Resource Group' $mgmtRg 'Created/Verified'

    New-LandingZoneResourceGroup -Name $dataRg -Location $config.location -Tags $tags -WhatIf:$WhatIfPreference | Out-Null
    Add-SummaryRow 'Resource Group' $dataRg 'Created/Verified'

    if ($effectiveIncludeNetwork) {
        New-LandingZoneResourceGroup -Name $networkRg -Location $config.location -Tags $tags -WhatIf:$WhatIfPreference | Out-Null
        Add-SummaryRow 'Resource Group' $networkRg 'Created/Verified'
    }
    else {
        Add-SummaryRow 'Resource Group' $networkRg 'Skipped (IncludeNetwork off)'
    }

    # 2. RBAC (continue-on-error by design)
    Write-LzLog -Message '--- Step 2: RBAC role assignment ---' -Level Info -LogPath $logPath
    foreach ($rgName in @($mgmtRg, $dataRg)) {
        $rbacResult = New-LandingZoneRoleAssignment -ObjectId $config.rbacPrincipalObjectId -RoleDefinitionName 'Reader' -ResourceGroupName $rgName -WhatIf:$WhatIfPreference
        if ($rbacResult) {
            Add-SummaryRow 'RBAC (Reader)' $rgName 'Assigned/Verified'
        }
        else {
            Add-SummaryRow 'RBAC (Reader)' $rgName 'Skipped (non-fatal - check placeholder object ID)'
        }
    }

    # 3. Policy assignment
    Write-LzLog -Message '--- Step 3: Policy assignment ---' -Level Info -LogPath $logPath
    New-LandingZonePolicyAssignment -ResourceGroupName $mgmtRg -TagName $config.tagPolicyName -WhatIf:$WhatIfPreference | Out-Null
    Add-SummaryRow 'Policy Assignment' 'inherit-tag-lzlite' 'Assigned/Verified'

    # 4. Budget
    Write-LzLog -Message '--- Step 4: Consumption budget ---' -Level Info -LogPath $logPath
    if ($effectiveIncludeBudget) {
        New-LandingZoneBudget -Amount $config.budgetAmountUSD -ContactEmail $config.contactEmail -WhatIf:$WhatIfPreference | Out-Null
        Add-SummaryRow 'Consumption Budget' 'budget-lzlite-monthly' "Created/Verified (`$$($config.budgetAmountUSD)/mo)"
    }
    else {
        Add-SummaryRow 'Consumption Budget' 'budget-lzlite-monthly' 'Skipped (IncludeBudget off)'
    }

    # 5. Storage account
    Write-LzLog -Message '--- Step 5: Storage account ---' -Level Info -LogPath $logPath
    $storageAccountName = "stlzlite$($config.uniqueSuffix)"
    New-LandingZoneStorageAccount -Name $storageAccountName -ResourceGroupName $dataRg -Location $config.location -Tags $tags -WhatIf:$WhatIfPreference | Out-Null
    Add-SummaryRow 'Storage Account' $storageAccountName 'Created/Verified'

    # 6. Key Vault
    Write-LzLog -Message '--- Step 6: Key Vault ---' -Level Info -LogPath $logPath
    $keyVaultName = "kv-lzlite-$($config.uniqueSuffix)"
    New-LandingZoneKeyVault -Name $keyVaultName -ResourceGroupName $dataRg -Location $config.location -Tags $tags -WhatIf:$WhatIfPreference | Out-Null
    Add-SummaryRow 'Key Vault' $keyVaultName 'Created/Verified'

    # 7. Network spoke (optional)
    Write-LzLog -Message '--- Step 7: Network spoke (optional) ---' -Level Info -LogPath $logPath
    if ($effectiveIncludeNetwork) {
        New-LandingZoneNetworkSpoke -ResourceGroupName $networkRg -Location $config.location -Tags $tags -WhatIf:$WhatIfPreference | Out-Null
        Add-SummaryRow 'Network Spoke' 'vnet-lzlite-spoke-eastus' 'Created/Verified'
    }
    else {
        Add-SummaryRow 'Network Spoke' 'vnet-lzlite-spoke-eastus' 'Skipped (IncludeNetwork off)'
    }

    Write-LzLog -Message 'Deployment steps completed.' -Level Success -LogPath $logPath
}
catch {
    Write-LzLog -Message "Deployment failed: $($_.Exception.Message)" -Level Error -LogPath $logPath
    throw
}
finally {
    Write-Host ''
    Write-Host '=== LandingZoneLite Deployment Summary ===' -ForegroundColor Yellow
    $summary | Format-Table -AutoSize | Out-String | Write-Host
    Write-LzLog -Message "Deployment summary written to console. Full log at '$logPath'." -Level Info -LogPath $logPath
}
