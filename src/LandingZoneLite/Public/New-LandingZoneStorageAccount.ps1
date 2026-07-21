function New-LandingZoneStorageAccount {
    <#
    .SYNOPSIS
        Idempotently creates a secure, low-cost storage account with bootstrap containers.

    .DESCRIPTION
        Creates a Standard_LRS storage account with secure transfer required, TLS 1.2 minimum,
        and public blob access disabled, then ensures the 'bootstrap-logs' and 'artifacts'
        containers exist. The storage account name is validated for length (3-24 characters) via
        Test-LzNameLength before any API calls are made. Idempotent: if the storage account
        already exists, its properties are not recreated, and container creation itself is
        idempotent (existing containers are left alone).

    .PARAMETER Name
        The storage account name (must be globally unique, lowercase letters/numbers only, 3-24
        chars), e.g. 'stlziteabc123'.

    .PARAMETER ResourceGroupName
        The resource group in which to create the storage account.

    .PARAMETER Location
        The Azure region, e.g. 'eastus'.

    .PARAMETER Tags
        A hashtable of tags to apply to the storage account.

    .EXAMPLE
        New-LandingZoneStorageAccount -Name 'stlziteabc123' -ResourceGroupName 'rg-lzlite-data-eastus' -Location 'eastus' -Tags $tags

    .EXAMPLE
        New-LandingZoneStorageAccount -Name 'stlziteabc123' -ResourceGroupName 'rg-lzlite-data-eastus' -Location 'eastus' -Tags $tags -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Location,

        [Parameter(Mandatory = $true)]
        [hashtable]$Tags
    )

    if (-not (Test-LzNameLength -Name $Name -MinLength 3 -MaxLength 24)) {
        throw "Storage account name '$Name' is invalid: must be between 3 and 24 characters."
    }

    try {
        $existing = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction SilentlyContinue

        if (-not $existing) {
            if ($PSCmdlet.ShouldProcess($Name, 'Create storage account')) {
                Write-LzLog -Message "Creating storage account '$Name' in '$ResourceGroupName'." -Level Info
                $existing = New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
                    -Name $Name `
                    -Location $Location `
                    -SkuName 'Standard_LRS' `
                    -Kind 'StorageV2' `
                    -MinimumTlsVersion 'TLS1_2' `
                    -EnableHttpsTrafficOnly $true `
                    -AllowBlobPublicAccess $false `
                    -Tag $Tags `
                    -ErrorAction Stop
                Write-LzLog -Message "Storage account '$Name' created successfully." -Level Success
            }
        }
        else {
            Write-LzLog -Message "Storage account '$Name' already exists. Skipping creation (idempotent)." -Level Info
        }

        if ($PSCmdlet.ShouldProcess($Name, 'Ensure bootstrap containers exist')) {
            $context = if ($existing) { $existing.Context } else { $null }
            if ($context) {
                foreach ($containerName in @('bootstrap-logs', 'artifacts')) {
                    $existingContainer = Get-AzStorageContainer -Name $containerName -Context $context -ErrorAction SilentlyContinue
                    if (-not $existingContainer) {
                        Write-LzLog -Message "Creating container '$containerName' in '$Name'." -Level Info
                        New-AzStorageContainer -Name $containerName -Context $context -Permission Off -ErrorAction Stop | Out-Null
                    }
                    else {
                        Write-LzLog -Message "Container '$containerName' already exists. Skipping (idempotent)." -Level Info
                    }
                }
            }
        }

        return $existing
    }
    catch {
        Write-LzLog -Message "Failed to create storage account '$Name': $($_.Exception.Message)" -Level Error
        throw
    }
}
