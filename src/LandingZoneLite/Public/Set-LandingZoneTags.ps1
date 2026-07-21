function Set-LandingZoneTags {
    <#
    .SYNOPSIS
        Applies (merges) the standard LandingZoneLite tag set onto an existing Azure resource or resource group.

    .DESCRIPTION
        Reads the current tags on the target resource (identified by -ResourceId or by -ResourceGroupName
        for a resource group), merges in the supplied tags (new values win on key collision), and writes
        the merged tag set back. This is idempotent — running it repeatedly with the same input tags
        converges to the same end state rather than duplicating or stacking tags.

    .PARAMETER ResourceId
        The full ARM resource ID of the target resource. Mutually exclusive with -ResourceGroupName.

    .PARAMETER ResourceGroupName
        The name of a resource group to tag directly. Mutually exclusive with -ResourceId.

    .PARAMETER Tags
        A hashtable of tags to merge onto the target.

    .EXAMPLE
        Set-LandingZoneTags -ResourceGroupName 'rg-lzlite-mgmt-eastus' -Tags @{ Environment = 'sandbox' }

    .EXAMPLE
        Set-LandingZoneTags -ResourceId '/subscriptions/xxxx/resourceGroups/rg-lzlite-data-eastus/providers/Microsoft.Storage/storageAccounts/stlziteabc123' -Tags $tags -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByResourceGroup')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceId')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceId,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceGroup')]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Tags
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'ByResourceGroup') {
            $target = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
            $currentTags = $target.Tags
            $targetDescription = "resource group '$ResourceGroupName'"
        }
        else {
            $target = Get-AzResource -ResourceId $ResourceId -ErrorAction Stop
            $currentTags = $target.Tags
            $targetDescription = "resource '$ResourceId'"
        }

        if (-not $currentTags) {
            $currentTags = @{}
        }

        $mergedTags = @{}
        foreach ($key in $currentTags.Keys) {
            $mergedTags[$key] = $currentTags[$key]
        }
        foreach ($key in $Tags.Keys) {
            $mergedTags[$key] = $Tags[$key]
        }

        if ($PSCmdlet.ShouldProcess($targetDescription, 'Apply merged tags')) {
            Write-LzLog -Message "Applying merged tags to $targetDescription." -Level Info

            if ($PSCmdlet.ParameterSetName -eq 'ByResourceGroup') {
                Set-AzResourceGroup -Name $ResourceGroupName -Tag $mergedTags -ErrorAction Stop | Out-Null
            }
            else {
                Set-AzResource -ResourceId $ResourceId -Tag $mergedTags -Force -ErrorAction Stop | Out-Null
            }

            Write-LzLog -Message "Tags applied successfully to $targetDescription." -Level Success
        }

        return $mergedTags
    }
    catch {
        Write-LzLog -Message "Failed to set tags on $($ResourceGroupName + $ResourceId): $($_.Exception.Message)" -Level Error
        throw
    }
}
