function Test-LzResourceGroupExists {
    <#
    .SYNOPSIS
        Checks whether an Azure resource group exists.

    .DESCRIPTION
        Thin wrapper around Get-AzResourceGroup that returns a boolean instead of throwing,
        enabling idempotent check-then-create patterns across the LandingZoneLite module.

    .PARAMETER Name
        The name of the resource group to check.

    .EXAMPLE
        if (-not (Test-LzResourceGroupExists -Name 'rg-lzlite-mgmt-eastus')) {
            New-AzResourceGroup -Name 'rg-lzlite-mgmt-eastus' -Location 'eastus'
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $rg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
        return [bool]$rg
    }
    catch {
        return $false
    }
}
