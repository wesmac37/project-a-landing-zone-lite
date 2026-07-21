function ConvertTo-LzTagHashtable {
    <#
    .SYNOPSIS
        Merges the standard LandingZoneLite tag set with optional extra tags into one hashtable.

    .DESCRIPTION
        Builds the canonical tag set applied to every resource group and resource created by the
        LandingZoneLite module: Environment, Project, Owner, CostCenter, ManagedBy, and DeployDate.
        Any additional tags supplied via -ExtraTags are merged in, with ExtraTags taking precedence
        over the standard defaults if the same key is supplied (allowing callers to override).

    .PARAMETER Environment
        The environment name (e.g. 'dev', 'sandbox', 'prod').

    .PARAMETER Owner
        The owner tag value, typically an email address or username.

    .PARAMETER CostCenter
        The cost center tag value.

    .PARAMETER ExtraTags
        Optional hashtable of additional tags to merge in. Keys here override standard keys.

    .PARAMETER DeployDate
        Optional ISO-8601 date string to stamp as DeployDate. Defaults to today's date (yyyy-MM-dd).

    .EXAMPLE
        ConvertTo-LzTagHashtable -Environment 'sandbox' -Owner 'jane@example.com' -CostCenter 'CC-100'

    .EXAMPLE
        ConvertTo-LzTagHashtable -Environment 'sandbox' -Owner 'jane@example.com' -CostCenter 'CC-100' -ExtraTags @{ Workload = 'lzlite' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Environment,

        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$CostCenter,

        [Parameter(Mandatory = $false)]
        [hashtable]$ExtraTags,

        [Parameter(Mandatory = $false)]
        [string]$DeployDate = (Get-Date -Format 'yyyy-MM-dd')
    )

    $baseTags = @{
        Environment = $Environment
        Project     = 'LandingZoneLite'
        Owner       = $Owner
        CostCenter  = $CostCenter
        ManagedBy   = 'PowerShell'
        DeployDate  = $DeployDate
    }

    if ($ExtraTags) {
        foreach ($key in $ExtraTags.Keys) {
            $baseTags[$key] = $ExtraTags[$key]
        }
    }

    return $baseTags
}
