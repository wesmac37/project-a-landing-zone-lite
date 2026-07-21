function Test-LzNameLength {
    <#
    .SYNOPSIS
        Validates that a resource name falls within Azure's allowed length range.

    .DESCRIPTION
        Internal helper that checks a candidate resource name against a minimum and maximum
        character length (typically driven by Azure resource-naming constraints, e.g. storage
        account names must be 3-24 characters). Returns $true when the name is valid, $false
        otherwise. Does not throw so callers can decide how to handle invalid names.

    .PARAMETER Name
        The candidate resource name to validate.

    .PARAMETER MinLength
        The minimum allowed length, inclusive. Defaults to 3.

    .PARAMETER MaxLength
        The maximum allowed length, inclusive. Defaults to 24 (Azure storage account limit).

    .EXAMPLE
        Test-LzNameLength -Name 'stlzliteabc123' -MinLength 3 -MaxLength 24
        Returns $true.

    .EXAMPLE
        Test-LzNameLength -Name 'thisstorageaccountnameiswaytoolongtobevalid' -MaxLength 24
        Returns $false.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [int]$MinLength = 3,

        [Parameter(Mandatory = $false)]
        [int]$MaxLength = 24
    )

    if ([string]::IsNullOrEmpty($Name)) {
        return $false
    }

    $length = $Name.Length
    if ($length -lt $MinLength -or $length -gt $MaxLength) {
        return $false
    }

    return $true
}
