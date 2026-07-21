function New-LandingZoneNetworkSpoke {
    <#
    .SYNOPSIS
        Idempotently creates a spoke-ready virtual network with a workload subnet and NSG.

    .DESCRIPTION
        Creates a small VNet (default 10.30.0.0/16) containing a single subnet 'snet-workload'
        (default 10.30.0.0/24) protected by a network security group, ready to be peered to a
        future hub network. This is the only piece of the landing zone that meaningfully grows
        resource count, so it is gated behind the caller's -IncludeNetwork intent (enforced by the
        calling script, not this function) and defaults to being skipped unless explicitly
        requested. Idempotent: existing VNet/subnet/NSG are detected and left as-is.

    .PARAMETER VNetName
        The virtual network name. Defaults to 'vnet-lzlite-spoke-eastus'.

    .PARAMETER VNetAddressPrefix
        The VNet address space. Defaults to '10.30.0.0/16'.

    .PARAMETER SubnetName
        The workload subnet name. Defaults to 'snet-workload'.

    .PARAMETER SubnetAddressPrefix
        The workload subnet address space. Defaults to '10.30.0.0/24'.

    .PARAMETER NsgName
        The network security group name. Defaults to 'nsg-lzlite-workload'.

    .PARAMETER ResourceGroupName
        The resource group in which to create the network resources.

    .PARAMETER Location
        The Azure region, e.g. 'eastus'.

    .PARAMETER Tags
        A hashtable of tags to apply to the network resources.

    .EXAMPLE
        New-LandingZoneNetworkSpoke -ResourceGroupName 'rg-lzlite-network-eastus' -Location 'eastus' -Tags $tags

    .EXAMPLE
        New-LandingZoneNetworkSpoke -ResourceGroupName 'rg-lzlite-network-eastus' -Location 'eastus' -Tags $tags -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$VNetName = 'vnet-lzlite-spoke-eastus',

        [Parameter(Mandatory = $false)]
        [string]$VNetAddressPrefix = '10.30.0.0/16',

        [Parameter(Mandatory = $false)]
        [string]$SubnetName = 'snet-workload',

        [Parameter(Mandatory = $false)]
        [string]$SubnetAddressPrefix = '10.30.0.0/24',

        [Parameter(Mandatory = $false)]
        [string]$NsgName = 'nsg-lzlite-workload',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Location,

        [Parameter(Mandatory = $true)]
        [hashtable]$Tags
    )

    try {
        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NsgName -ErrorAction SilentlyContinue

        if (-not $nsg) {
            if ($PSCmdlet.ShouldProcess($NsgName, 'Create network security group')) {
                Write-LzLog -Message "Creating NSG '$NsgName' in '$ResourceGroupName'." -Level Info
                $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName `
                    -Name $NsgName `
                    -Location $Location `
                    -Tag $Tags `
                    -ErrorAction Stop
                Write-LzLog -Message "NSG '$NsgName' created successfully." -Level Success
            }
        }
        else {
            Write-LzLog -Message "NSG '$NsgName' already exists. Skipping creation (idempotent)." -Level Info
        }

        $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue

        if (-not $vnet) {
            if ($PSCmdlet.ShouldProcess($VNetName, 'Create virtual network with workload subnet')) {
                Write-LzLog -Message "Creating VNet '$VNetName' ($VNetAddressPrefix) with subnet '$SubnetName' ($SubnetAddressPrefix)." -Level Info

                $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $SubnetName `
                    -AddressPrefix $SubnetAddressPrefix `
                    -NetworkSecurityGroup $nsg

                $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName `
                    -Name $VNetName `
                    -Location $Location `
                    -AddressPrefix $VNetAddressPrefix `
                    -Subnet $subnetConfig `
                    -Tag $Tags `
                    -ErrorAction Stop

                Write-LzLog -Message "VNet '$VNetName' created successfully with subnet '$SubnetName'." -Level Success
            }
        }
        else {
            Write-LzLog -Message "VNet '$VNetName' already exists. Skipping creation (idempotent)." -Level Info
        }

        return $vnet
    }
    catch {
        Write-LzLog -Message "Failed to create network spoke '$VNetName': $($_.Exception.Message)" -Level Error
        throw
    }
}
