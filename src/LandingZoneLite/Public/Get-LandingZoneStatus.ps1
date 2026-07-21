function Get-LandingZoneStatus {
    <#
    .SYNOPSIS
        Reports the current deployed/missing status of every LandingZoneLite component.

    .DESCRIPTION
        Performs a read-only survey of the landing zone footprint: resource groups, storage
        account configuration, Key Vault configuration, policy assignment, budget, and (optionally)
        network resources. Returns a collection of PSCustomObject status records, one per checked
        component, each with Component, Target, Status ('Pass'/'Fail'/'Skipped'), and Detail
        fields. Used by scripts/validate.ps1 to build the PASS/FAIL report. Never throws for
        missing resources — a missing resource is reported as a 'Fail' status record, not an
        exception.

    .PARAMETER ManagementRg
        The management resource group name.

    .PARAMETER DataRg
        The data resource group name.

    .PARAMETER NetworkRg
        The network resource group name (only checked if -IncludeNetwork is set).

    .PARAMETER StorageAccountName
        The storage account name to check.

    .PARAMETER KeyVaultName
        The Key Vault name to check.

    .PARAMETER BudgetName
        The consumption budget name to check.

    .PARAMETER PolicyAssignmentName
        The policy assignment name to check.

    .PARAMETER IncludeNetwork
        Whether network resources should be checked (and expected to exist).

    .PARAMETER IncludeBudget
        Whether the budget should be checked (and expected to exist).

    .PARAMETER RequiredTags
        The list of tag keys that every resource group must have. Defaults to the standard
        LandingZoneLite tag set.

    .EXAMPLE
        Get-LandingZoneStatus -ManagementRg 'rg-lzlite-mgmt-eastus' -DataRg 'rg-lzlite-data-eastus' -StorageAccountName 'stlziteabc123' -KeyVaultName 'kv-lzlite-abc123' -BudgetName 'budget-lzlite-monthly' -PolicyAssignmentName 'inherit-tag-lzlite' -IncludeBudget
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagementRg,

        [Parameter(Mandatory = $true)]
        [string]$DataRg,

        [Parameter(Mandatory = $false)]
        [string]$NetworkRg = 'rg-lzlite-network-eastus',

        [Parameter(Mandatory = $true)]
        [string]$StorageAccountName,

        [Parameter(Mandatory = $true)]
        [string]$KeyVaultName,

        [Parameter(Mandatory = $false)]
        [string]$BudgetName = 'budget-lzlite-monthly',

        [Parameter(Mandatory = $false)]
        [string]$PolicyAssignmentName = 'inherit-tag-lzlite',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeNetwork,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeBudget,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredTags = @('Environment', 'Project', 'Owner', 'CostCenter', 'ManagedBy', 'DeployDate')
    )

    $results = [System.Collections.Generic.List[object]]::new()

    function New-StatusRecord {
        param($Component, $Target, $Status, $Detail)
        [PSCustomObject]@{
            Component = $Component
            Target    = $Target
            Status    = $Status
            Detail    = $Detail
        }
    }

    # --- Resource groups + required tags ---
    foreach ($rgInfo in @(
            @{ Name = $ManagementRg; Label = 'Resource Group (mgmt)' },
            @{ Name = $DataRg; Label = 'Resource Group (data)' }
        )) {
        try {
            $rg = Get-AzResourceGroup -Name $rgInfo.Name -ErrorAction Stop
            $missingTags = @($RequiredTags | Where-Object { -not $rg.Tags -or -not $rg.Tags.ContainsKey($_) })
            if ($missingTags.Count -eq 0) {
                $results.Add((New-StatusRecord $rgInfo.Label $rgInfo.Name 'Pass' 'Exists with all required tags'))
            }
            else {
                $results.Add((New-StatusRecord $rgInfo.Label $rgInfo.Name 'Fail' "Missing tags: $($missingTags -join ', ')"))
            }
        }
        catch {
            $results.Add((New-StatusRecord $rgInfo.Label $rgInfo.Name 'Fail' 'Resource group not found'))
        }
    }

    # --- Network resource group (only expected if IncludeNetwork) ---
    if ($IncludeNetwork) {
        try {
            $rg = Get-AzResourceGroup -Name $NetworkRg -ErrorAction Stop
            $missingTags = @($RequiredTags | Where-Object { -not $rg.Tags -or -not $rg.Tags.ContainsKey($_) })
            if ($missingTags.Count -eq 0) {
                $results.Add((New-StatusRecord 'Resource Group (network)' $NetworkRg 'Pass' 'Exists with all required tags'))
            }
            else {
                $results.Add((New-StatusRecord 'Resource Group (network)' $NetworkRg 'Fail' "Missing tags: $($missingTags -join ', ')"))
            }
        }
        catch {
            $results.Add((New-StatusRecord 'Resource Group (network)' $NetworkRg 'Fail' 'Resource group not found'))
        }
    }
    else {
        $results.Add((New-StatusRecord 'Resource Group (network)' $NetworkRg 'Skipped' '-IncludeNetwork not requested'))
    }

    # --- Storage account ---
    try {
        $sa = Get-AzStorageAccount -ResourceGroupName $DataRg -Name $StorageAccountName -ErrorAction Stop
        $checks = @()
        if (-not $sa.EnableHttpsTrafficOnly) { $checks += 'secure transfer disabled' }
        if ($sa.MinimumTlsVersion -ne 'TLS1_2') { $checks += 'TLS min version not 1.2' }
        if ($sa.AllowBlobPublicAccess) { $checks += 'public blob access enabled' }

        if ($checks.Count -eq 0) {
            $results.Add((New-StatusRecord 'Storage Account' $StorageAccountName 'Pass' 'Secure transfer on, TLS1.2 minimum, public access disabled'))
        }
        else {
            $results.Add((New-StatusRecord 'Storage Account' $StorageAccountName 'Fail' ($checks -join '; ')))
        }
    }
    catch {
        $results.Add((New-StatusRecord 'Storage Account' $StorageAccountName 'Fail' 'Storage account not found'))
    }

    # --- Key Vault ---
    try {
        $kv = Get-AzKeyVault -ResourceGroupName $DataRg -VaultName $KeyVaultName -ErrorAction Stop
        if ($kv.EnableRbacAuthorization) {
            $results.Add((New-StatusRecord 'Key Vault' $KeyVaultName 'Pass' 'Exists with RBAC authorization enabled'))
        }
        else {
            $results.Add((New-StatusRecord 'Key Vault' $KeyVaultName 'Fail' 'RBAC authorization not enabled'))
        }
    }
    catch {
        $results.Add((New-StatusRecord 'Key Vault' $KeyVaultName 'Fail' 'Key Vault not found'))
    }

    # --- Policy assignment ---
    try {
        $rg = Get-AzResourceGroup -Name $ManagementRg -ErrorAction Stop
        $policy = Get-AzPolicyAssignment -Name $PolicyAssignmentName -Scope $rg.ResourceId -ErrorAction Stop
        if ($policy) {
            $results.Add((New-StatusRecord 'Policy Assignment' $PolicyAssignmentName 'Pass' "Assigned at scope $($rg.ResourceId)"))
        }
    }
    catch {
        $results.Add((New-StatusRecord 'Policy Assignment' $PolicyAssignmentName 'Fail' 'Policy assignment not found at expected scope'))
    }

    # --- Budget ---
    if ($IncludeBudget) {
        try {
            $budget = Get-AzConsumptionBudget -Name $BudgetName -ErrorAction Stop
            if ($budget) {
                $results.Add((New-StatusRecord 'Consumption Budget' $BudgetName 'Pass' "Amount: $($budget.Amount)"))
            }
        }
        catch {
            $results.Add((New-StatusRecord 'Consumption Budget' $BudgetName 'Fail' 'Budget not found'))
        }
    }
    else {
        $results.Add((New-StatusRecord 'Consumption Budget' $BudgetName 'Skipped' '-IncludeBudget not requested'))
    }

    # --- Network spoke resources ---
    if ($IncludeNetwork) {
        try {
            $vnet = Get-AzVirtualNetwork -ResourceGroupName $NetworkRg -Name 'vnet-lzlite-spoke-eastus' -ErrorAction Stop
            if ($vnet) {
                $results.Add((New-StatusRecord 'Virtual Network' 'vnet-lzlite-spoke-eastus' 'Pass' "Address space: $($vnet.AddressSpace.AddressPrefixes -join ', ')"))
            }
        }
        catch {
            $results.Add((New-StatusRecord 'Virtual Network' 'vnet-lzlite-spoke-eastus' 'Fail' 'VNet not found'))
        }
    }
    else {
        $results.Add((New-StatusRecord 'Virtual Network' 'vnet-lzlite-spoke-eastus' 'Skipped' '-IncludeNetwork not requested'))
    }

    return $results.ToArray()
}
