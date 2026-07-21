function New-LandingZoneResourceGroup {
    <#
    .SYNOPSIS
        Idempotently creates (or verifies) an Azure resource group with standard LandingZoneLite tags.

    .DESCRIPTION
        Checks whether the target resource group already exists. If it does, the existing resource
        group object is returned unchanged (no-op). If it does not exist, it is created with the
        supplied location and tags. Supports -WhatIf/-Confirm via SupportsShouldProcess.

    .PARAMETER Name
        The resource group name, e.g. 'rg-lzlite-mgmt-eastus'.

    .PARAMETER Location
        The Azure region to create the resource group in, e.g. 'eastus'.

    .PARAMETER Tags
        A hashtable of tags to apply to the resource group. Typically produced by
        ConvertTo-LzTagHashtable.

    .EXAMPLE
        $tags = ConvertTo-LzTagHashtable -Environment 'sandbox' -Owner 'jane@example.com' -CostCenter 'CC-100'
        New-LandingZoneResourceGroup -Name 'rg-lzlite-mgmt-eastus' -Location 'eastus' -Tags $tags

    .EXAMPLE
        New-LandingZoneResourceGroup -Name 'rg-lzlite-mgmt-eastus' -Location 'eastus' -Tags $tags -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(1, 90)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Location,

        [Parameter(Mandatory = $true)]
        [hashtable]$Tags
    )

    try {
        $existing = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue

        if ($existing) {
            Write-LzLog -Message "Resource group '$Name' already exists. Skipping creation (idempotent)." -Level Info
            return $existing
        }

        if ($PSCmdlet.ShouldProcess($Name, "Create resource group in $Location")) {
            Write-LzLog -Message "Creating resource group '$Name' in '$Location'." -Level Info
            $rg = New-AzResourceGroup -Name $Name -Location $Location -Tag $Tags -ErrorAction Stop
            Write-LzLog -Message "Resource group '$Name' created successfully." -Level Success
            return $rg
        }
    }
    catch {
        Write-LzLog -Message "Failed to create resource group '$Name': $($_.Exception.Message)" -Level Error
        throw
    }
}
