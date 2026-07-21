function New-LandingZonePolicyAssignment {
    <#
    .SYNOPSIS
        Idempotently assigns the built-in "Inherit a tag from the resource group if missing" Azure Policy at a resource-group scope.

    .DESCRIPTION
        Uses the well-known built-in policy definition ID for "Inherit a tag from the resource
        group if missing" (611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f) to assign a tag-inheritance policy
        at the specified resource group scope. This is the governance-as-code piece of the landing
        zone: it ensures resources within scope automatically inherit a given tag (e.g.
        'Environment') from their resource group when the resource itself is missing that tag.
        Idempotent: if an assignment with the same name already exists at scope, it is returned
        as-is rather than re-created.

    .PARAMETER ResourceGroupName
        The resource group scope at which to assign the policy.

    .PARAMETER TagName
        The name of the tag that should be inherited from the resource group. Defaults to 'Environment'.

    .PARAMETER AssignmentName
        The name to give the policy assignment. Defaults to 'inherit-tag-lzlite'.

    .EXAMPLE
        New-LandingZonePolicyAssignment -ResourceGroupName 'rg-lzlite-mgmt-eastus' -TagName 'Environment'

    .EXAMPLE
        New-LandingZonePolicyAssignment -ResourceGroupName 'rg-lzlite-mgmt-eastus' -TagName 'Environment' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $false)]
        [string]$TagName = 'Environment',

        [Parameter(Mandatory = $false)]
        [string]$AssignmentName = 'inherit-tag-lzlite'
    )

    # Well-known built-in policy definition: "Inherit a tag from the resource group if missing"
    $policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f'

    try {
        $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop
        $scope = $rg.ResourceId

        $existing = Get-AzPolicyAssignment -Name $AssignmentName -Scope $scope -ErrorAction SilentlyContinue

        if ($existing) {
            Write-LzLog -Message "Policy assignment '$AssignmentName' already exists at scope '$scope'. Skipping (idempotent)." -Level Info
            return $existing
        }

        $policyDefinition = Get-AzPolicyDefinition -Id $policyDefinitionId -ErrorAction Stop
        $policyParams = @{ tagName = @{ value = $TagName } }

        if ($PSCmdlet.ShouldProcess($scope, "Assign policy '$AssignmentName' (tag inheritance for '$TagName')")) {
            Write-LzLog -Message "Assigning tag-inheritance policy for tag '$TagName' at scope '$scope'." -Level Info
            $assignment = New-AzPolicyAssignment -Name $AssignmentName `
                -Scope $scope `
                -PolicyDefinition $policyDefinition `
                -PolicyParameterObject $policyParams `
                -ErrorAction Stop
            Write-LzLog -Message "Policy assignment '$AssignmentName' created successfully." -Level Success
            return $assignment
        }
    }
    catch {
        Write-LzLog -Message "Failed to create policy assignment '$AssignmentName' at '$ResourceGroupName': $($_.Exception.Message)" -Level Error
        throw
    }
}
