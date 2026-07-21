function New-LandingZoneKeyVault {
    <#
    .SYNOPSIS
        Idempotently creates an RBAC-authorized, soft-delete-enabled Key Vault with a demo secret.

    .DESCRIPTION
        Creates a Key Vault configured for Azure RBAC authorization (rather than legacy access
        policies) with soft-delete enabled, then ensures a demo secret named 'SampleAppSetting'
        exists in the vault. Idempotent: if the vault already exists it is not recreated, and the
        demo secret is only written if it doesn't already exist (or is re-set to the same value,
        which is a safe no-op).

    .PARAMETER Name
        The Key Vault name (must be globally unique, 3-24 chars), e.g. 'kv-lzlite-abc123'.

    .PARAMETER ResourceGroupName
        The resource group in which to create the Key Vault.

    .PARAMETER Location
        The Azure region, e.g. 'eastus'.

    .PARAMETER Tags
        A hashtable of tags to apply to the Key Vault.

    .PARAMETER SecretValue
        The value to store in the demo secret 'SampleAppSetting'. Defaults to a placeholder string.

    .EXAMPLE
        New-LandingZoneKeyVault -Name 'kv-lzlite-abc123' -ResourceGroupName 'rg-lzlite-data-eastus' -Location 'eastus' -Tags $tags

    .EXAMPLE
        New-LandingZoneKeyVault -Name 'kv-lzlite-abc123' -ResourceGroupName 'rg-lzlite-data-eastus' -Location 'eastus' -Tags $tags -WhatIf
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
        [hashtable]$Tags,

        [Parameter(Mandatory = $false)]
        [string]$SecretValue = 'sample-value-replace-me'
    )

    if (-not (Test-LzNameLength -Name $Name -MinLength 3 -MaxLength 24)) {
        throw "Key Vault name '$Name' is invalid: must be between 3 and 24 characters."
    }

    try {
        $existing = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $Name -ErrorAction SilentlyContinue

        if (-not $existing) {
            if ($PSCmdlet.ShouldProcess($Name, 'Create Key Vault')) {
                Write-LzLog -Message "Creating Key Vault '$Name' in '$ResourceGroupName'." -Level Info
                $existing = New-AzKeyVault -ResourceGroupName $ResourceGroupName `
                    -VaultName $Name `
                    -Location $Location `
                    -EnableRbacAuthorization $true `
                    -EnableSoftDelete $true `
                    -SoftDeleteRetentionInDays 7 `
                    -Tag $Tags `
                    -ErrorAction Stop
                Write-LzLog -Message "Key Vault '$Name' created successfully." -Level Success
            }
        }
        else {
            Write-LzLog -Message "Key Vault '$Name' already exists. Skipping creation (idempotent)." -Level Info
        }

        if ($PSCmdlet.ShouldProcess($Name, "Ensure demo secret 'SampleAppSetting' exists")) {
            $existingSecret = Get-AzKeyVaultSecret -VaultName $Name -Name 'SampleAppSetting' -ErrorAction SilentlyContinue
            if (-not $existingSecret) {
                Write-LzLog -Message "Creating demo secret 'SampleAppSetting' in vault '$Name'." -Level Info
                $secureValue = ConvertTo-SecureString -String $SecretValue -AsPlainText -Force
                Set-AzKeyVaultSecret -VaultName $Name -Name 'SampleAppSetting' -SecretValue $secureValue -ErrorAction Stop | Out-Null
            }
            else {
                Write-LzLog -Message "Demo secret 'SampleAppSetting' already exists in vault '$Name'. Skipping (idempotent)." -Level Info
            }
        }

        return $existing
    }
    catch {
        Write-LzLog -Message "Failed to create Key Vault '$Name': $($_.Exception.Message)" -Level Error
        throw
    }
}
