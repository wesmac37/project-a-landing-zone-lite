function Get-LzUniqueSuffix {
    <#
    .SYNOPSIS
        Generates a random lowercase alphabetic suffix for globally-unique Azure resource names.

    .DESCRIPTION
        Internal helper used to produce a short, lowercase, letters-only suffix (default 6
        characters) suitable for appending to storage account and Key Vault names to satisfy
        Azure's global uniqueness requirements. Uses Get-Random under the hood.

    .PARAMETER Length
        The number of characters to generate. Defaults to 6.

    .EXAMPLE
        Get-LzUniqueSuffix
        Returns something like 'kqzmta'.

    .EXAMPLE
        Get-LzUniqueSuffix -Length 8
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 24)]
        [int]$Length = 6
    )

    $chars = 97..122 | Get-Random -Count $Length | ForEach-Object { [char]$_ }
    return -join $chars
}
