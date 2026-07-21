function New-LandingZoneRoleAssignment {
    <#
    .SYNOPSIS
        Idempotently grants a built-in Azure RBAC role to a principal at a resource-group scope.

    .DESCRIPTION
        Wraps New-AzRoleAssignment with idempotent check-then-create logic and a non-fatal error
        path: because the placeholder principal object ID documented in config may not exist in
        every tenant, failures here are caught, logged as warnings, and execution continues rather
        than aborting the whole deployment. This mirrors the "continue on error" behavior called
        for by the build spec for RBAC bootstrap steps.

    .PARAMETER ObjectId
        The Azure AD object ID (user, group, or service principal) to grant the role to. This is
        typically a placeholder the user must replace with a real object ID from their tenant.

    .PARAMETER RoleDefinitionName
        The built-in role name to grant, e.g. 'Reader'. Defaults to 'Reader'.

    .PARAMETER ResourceGroupName
        The resource group scope at which to grant the role assignment.

    .EXAMPLE
        New-LandingZoneRoleAssignment -ObjectId '00000000-0000-0000-0000-000000000000' -ResourceGroupName 'rg-lzlite-mgmt-eastus'

    .EXAMPLE
        New-LandingZoneRoleAssignment -ObjectId $groupObjectId -RoleDefinitionName 'Reader' -ResourceGroupName 'rg-lzlite-data-eastus' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter(Mandatory = $false)]
        [string]$RoleDefinitionName = 'Reader',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName
    )

    try {
        # Build the resource-group scope deterministically from the current subscription ID and
        # the resource group name, rather than depending on Get-AzResourceGroup returning a live
        # object. Under -WhatIf, a resource group that is being created earlier in the same run
        # (e.g. by New-LandingZoneResourceGroup) genuinely does not exist yet, so Get-AzResourceGroup
        # would return $null there - relying on '$rg.ResourceId' would then fail even though the
        # scope path itself is fully predictable from subscription ID + resource group name.
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context -or -not $context.Subscription -or -not $context.Subscription.Id) {
            throw 'No active Az context/subscription was found while building the role assignment scope.'
        }
        $scope = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$ResourceGroupName"

        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if (-not $rg) {
            Write-LzLog -Message "Resource group '$ResourceGroupName' was not found (it may be created earlier in this same run under -WhatIf). Proceeding with the computed scope '$scope'." -Level Info
        }

        $existing = Get-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleDefinitionName -Scope $scope -ErrorAction SilentlyContinue

        if ($existing) {
            Write-LzLog -Message "Role assignment '$RoleDefinitionName' for object '$ObjectId' already exists at scope '$scope'. Skipping (idempotent)." -Level Info
            return $existing
        }

        if ($PSCmdlet.ShouldProcess($scope, "Grant '$RoleDefinitionName' to object '$ObjectId'")) {
            Write-LzLog -Message "Granting '$RoleDefinitionName' to object '$ObjectId' at scope '$scope'." -Level Info
            $assignment = New-AzRoleAssignment -ObjectId $ObjectId -RoleDefinitionName $RoleDefinitionName -Scope $scope -ErrorAction Stop
            Write-LzLog -Message "Role assignment created successfully." -Level Success
            return $assignment
        }
    }
    catch {
        # Non-fatal by design: the placeholder principal object ID may not exist in this tenant.
        # RBAC bootstrap failures must not abort the rest of the deployment.
        Write-LzLog -Message "RBAC assignment for object '$ObjectId' at '$ResourceGroupName' failed and was skipped (continue-on-error): $($_.Exception.Message)" -Level Warning
        return $null
    }
}
