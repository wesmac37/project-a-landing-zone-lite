#Requires -Version 7.0
<#
.SYNOPSIS
    Removes all LandingZoneLite resources in dependency-safe order.

.DESCRIPTION
    Tears down everything deploy.ps1 may have created: resource locks (if any), role assignments,
    the policy assignment, the consumption budget, the Key Vault (with optional purge), the
    storage account, network resources (if present), and finally the resource groups themselves.
    Every removal step is wrapped in try/catch and checks for existence first, so re-running
    cleanup.ps1 against an already-clean environment produces no errors (fully idempotent).
    Supports -WhatIf and -Force.

.PARAMETER ConfigPath
    Path to the landingzone.config.json file. Defaults to ../config/landingzone.config.json
    relative to this script.

.PARAMETER PurgeKeyVault
    Switch to also purge the Key Vault after soft-delete (permanently removes it). Without this
    switch, the vault is only soft-deleted and can be recovered within the retention window.

.PARAMETER Force
    Suppresses confirmation prompts for destructive operations.

.PARAMETER WhatIf
    Standard PowerShell risk-mitigation switch. Shows what would be removed without removing it.

.EXAMPLE
    ./cleanup.ps1 -WhatIf
    Shows everything that would be removed without making changes.

.EXAMPLE
    ./cleanup.ps1 -Force
    Removes all LandingZoneLite resources without confirmation prompts.

.EXAMPLE
    ./cleanup.ps1 -Force -PurgeKeyVault
    Removes all resources and permanently purges the soft-deleted Key Vault.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..' 'config' 'landingzone.config.json'),

    [Parameter(Mandatory = $false)]
    [switch]$PurgeKeyVault,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..' 'src' 'LandingZoneLite' 'LandingZoneLite.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

$logDirectory = Join-Path $PSScriptRoot '..' 'logs'
if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logDirectory "cleanup-$timestamp.log"

Write-LzLog -Message "Starting LandingZoneLite cleanup. Log: $logPath" -Level Info -LogPath $logPath

if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found at '$ConfigPath'."
}
$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

if ($Force) {
    $ConfirmPreference = 'None'
}

$mgmtRg    = 'rg-lzlite-mgmt-eastus'
$dataRg    = 'rg-lzlite-data-eastus'
$networkRg = 'rg-lzlite-network-eastus'
$storageAccountName = "stlzlite$($config.uniqueSuffix)"
$keyVaultName = "kv-lzlite-$($config.uniqueSuffix)"

function Remove-LzResourceLockSafe {
    param([string]$ResourceGroupName)
    try {
        $locks = Get-AzResourceLock -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
        foreach ($lock in @($locks)) {
            if ($PSCmdlet.ShouldProcess($lock.Name, "Remove resource lock on $ResourceGroupName")) {
                Write-LzLog -Message "Removing lock '$($lock.Name)' on '$ResourceGroupName'." -Level Info -LogPath $logPath
                Remove-AzResourceLock -LockId $lock.LockId -Force -ErrorAction Stop | Out-Null
            }
        }
        if (-not $locks) {
            Write-LzLog -Message "No resource locks found on '$ResourceGroupName' (idempotent no-op)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping lock removal for '$ResourceGroupName': $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }
}

function Remove-LzRoleAssignmentSafe {
    param([string]$ResourceGroupName, [string]$ObjectId)
    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-LzLog -Message "Resource group '$ResourceGroupName' not found; nothing to remove for role assignments (idempotent)." -Level Info -LogPath $logPath
            return
        }
        $assignments = Get-AzRoleAssignment -ObjectId $ObjectId -Scope $rg.ResourceId -ErrorAction SilentlyContinue
        foreach ($assignment in @($assignments)) {
            if ($PSCmdlet.ShouldProcess($assignment.RoleAssignmentId, 'Remove role assignment')) {
                Write-LzLog -Message "Removing role assignment '$($assignment.RoleDefinitionName)' for object '$ObjectId' at '$ResourceGroupName'." -Level Info -LogPath $logPath
                Remove-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $assignment.RoleDefinitionName -Scope $rg.ResourceId -ErrorAction Stop
            }
        }
        if (-not $assignments) {
            Write-LzLog -Message "No role assignments found for object '$ObjectId' at '$ResourceGroupName' (idempotent no-op)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping role assignment removal for '$ResourceGroupName': $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }
}

try {
    # 1. Resource locks
    Write-LzLog -Message '--- Step 1: Resource locks ---' -Level Info -LogPath $logPath
    foreach ($rgName in @($mgmtRg, $dataRg, $networkRg)) {
        Remove-LzResourceLockSafe -ResourceGroupName $rgName
    }

    # 2. Role assignments
    Write-LzLog -Message '--- Step 2: Role assignments ---' -Level Info -LogPath $logPath
    foreach ($rgName in @($mgmtRg, $dataRg)) {
        Remove-LzRoleAssignmentSafe -ResourceGroupName $rgName -ObjectId $config.rbacPrincipalObjectId
    }

    # 3. Policy assignment
    Write-LzLog -Message '--- Step 3: Policy assignment ---' -Level Info -LogPath $logPath
    try {
        $rg = Get-AzResourceGroup -Name $mgmtRg -ErrorAction SilentlyContinue
        if ($rg) {
            $policy = Get-AzPolicyAssignment -Name 'inherit-tag-lzlite' -Scope $rg.ResourceId -ErrorAction SilentlyContinue
            if ($policy) {
                if ($PSCmdlet.ShouldProcess('inherit-tag-lzlite', 'Remove policy assignment')) {
                    Write-LzLog -Message "Removing policy assignment 'inherit-tag-lzlite'." -Level Info -LogPath $logPath
                    Remove-AzPolicyAssignment -Name 'inherit-tag-lzlite' -Scope $rg.ResourceId -ErrorAction Stop | Out-Null
                }
            }
            else {
                Write-LzLog -Message "Policy assignment 'inherit-tag-lzlite' not found (idempotent no-op)." -Level Info -LogPath $logPath
            }
        }
        else {
            Write-LzLog -Message "Resource group '$mgmtRg' not found; nothing to remove for policy assignment (idempotent)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping policy assignment removal: $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }

    # 4. Budget
    Write-LzLog -Message '--- Step 4: Consumption budget ---' -Level Info -LogPath $logPath
    try {
        $budget = Get-AzConsumptionBudget -Name 'budget-lzlite-monthly' -ErrorAction SilentlyContinue
        if ($budget) {
            if ($PSCmdlet.ShouldProcess('budget-lzlite-monthly', 'Remove consumption budget')) {
                Write-LzLog -Message "Removing consumption budget 'budget-lzlite-monthly'." -Level Info -LogPath $logPath
                Remove-AzConsumptionBudget -Name 'budget-lzlite-monthly' -ErrorAction Stop
            }
        }
        else {
            Write-LzLog -Message "Budget 'budget-lzlite-monthly' not found (idempotent no-op)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping budget removal: $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }

    # 5. Key Vault (with optional purge)
    Write-LzLog -Message '--- Step 5: Key Vault ---' -Level Info -LogPath $logPath
    try {
        $kv = Get-AzKeyVault -ResourceGroupName $dataRg -VaultName $keyVaultName -ErrorAction SilentlyContinue
        if ($kv) {
            if ($PSCmdlet.ShouldProcess($keyVaultName, 'Remove Key Vault')) {
                Write-LzLog -Message "Removing Key Vault '$keyVaultName'." -Level Info -LogPath $logPath
                Remove-AzKeyVault -ResourceGroupName $dataRg -VaultName $keyVaultName -Force -ErrorAction Stop

                if ($PurgeKeyVault) {
                    Write-LzLog -Message "Purging soft-deleted Key Vault '$keyVaultName'." -Level Info -LogPath $logPath
                    Remove-AzKeyVault -VaultName $keyVaultName -Location $kv.Location -InRemovedState -Force -ErrorAction Stop
                }
            }
        }
        else {
            Write-LzLog -Message "Key Vault '$keyVaultName' not found (idempotent no-op)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping Key Vault removal: $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }

    # 6. Storage account
    Write-LzLog -Message '--- Step 6: Storage account ---' -Level Info -LogPath $logPath
    try {
        $sa = Get-AzStorageAccount -ResourceGroupName $dataRg -Name $storageAccountName -ErrorAction SilentlyContinue
        if ($sa) {
            if ($PSCmdlet.ShouldProcess($storageAccountName, 'Remove storage account')) {
                Write-LzLog -Message "Removing storage account '$storageAccountName'." -Level Info -LogPath $logPath
                Remove-AzStorageAccount -ResourceGroupName $dataRg -Name $storageAccountName -Force -ErrorAction Stop
            }
        }
        else {
            Write-LzLog -Message "Storage account '$storageAccountName' not found (idempotent no-op)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping storage account removal: $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }

    # 7. Network resources (if present)
    Write-LzLog -Message '--- Step 7: Network resources ---' -Level Info -LogPath $logPath
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $networkRg -Name 'vnet-lzlite-spoke-eastus' -ErrorAction SilentlyContinue
        if ($vnet) {
            if ($PSCmdlet.ShouldProcess('vnet-lzlite-spoke-eastus', 'Remove virtual network')) {
                Write-LzLog -Message 'Removing VNet vnet-lzlite-spoke-eastus.' -Level Info -LogPath $logPath
                Remove-AzVirtualNetwork -ResourceGroupName $networkRg -Name 'vnet-lzlite-spoke-eastus' -Force -ErrorAction Stop
            }
        }
        else {
            Write-LzLog -Message "VNet 'vnet-lzlite-spoke-eastus' not found (idempotent no-op)." -Level Info -LogPath $logPath
        }

        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $networkRg -Name 'nsg-lzlite-workload' -ErrorAction SilentlyContinue
        if ($nsg) {
            if ($PSCmdlet.ShouldProcess('nsg-lzlite-workload', 'Remove network security group')) {
                Write-LzLog -Message 'Removing NSG nsg-lzlite-workload.' -Level Info -LogPath $logPath
                Remove-AzNetworkSecurityGroup -ResourceGroupName $networkRg -Name 'nsg-lzlite-workload' -Force -ErrorAction Stop
            }
        }
        else {
            Write-LzLog -Message "NSG 'nsg-lzlite-workload' not found (idempotent no-op)." -Level Info -LogPath $logPath
        }
    }
    catch {
        Write-LzLog -Message "Skipping network resource removal: $($_.Exception.Message)" -Level Warning -LogPath $logPath
    }

    # 8. Resource groups (last, dependency-safe order)
    Write-LzLog -Message '--- Step 8: Resource groups ---' -Level Info -LogPath $logPath
    foreach ($rgName in @($networkRg, $dataRg, $mgmtRg)) {
        try {
            $rg = Get-AzResourceGroup -Name $rgName -ErrorAction SilentlyContinue
            if ($rg) {
                if ($PSCmdlet.ShouldProcess($rgName, 'Remove resource group')) {
                    Write-LzLog -Message "Removing resource group '$rgName'." -Level Info -LogPath $logPath
                    Remove-AzResourceGroup -Name $rgName -Force -ErrorAction Stop
                }
            }
            else {
                Write-LzLog -Message "Resource group '$rgName' not found (idempotent no-op)." -Level Info -LogPath $logPath
            }
        }
        catch {
            Write-LzLog -Message "Skipping resource group removal for '$rgName': $($_.Exception.Message)" -Level Warning -LogPath $logPath
        }
    }

    Write-LzLog -Message 'Cleanup completed.' -Level Success -LogPath $logPath
}
catch {
    Write-LzLog -Message "Cleanup encountered an unexpected error: $($_.Exception.Message)" -Level Error -LogPath $logPath
    throw
}
