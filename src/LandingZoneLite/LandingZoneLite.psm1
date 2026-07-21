#Requires -Version 7.0
<#
    LandingZoneLite.psm1
    Root module for the LandingZoneLite toolkit. Dot-sources every function under Public/ and
    Private/ and exports only the Public functions, keeping Private helpers internal to the
    module's session state.
#>

Set-StrictMode -Version Latest

$moduleRoot = $PSScriptRoot

$privateFunctions = @(Get-ChildItem -Path (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
$publicFunctions  = @(Get-ChildItem -Path (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

foreach ($function in @($privateFunctions + $publicFunctions)) {
    try {
        . $function.FullName
    }
    catch {
        Write-Error "Failed to dot-source '$($function.FullName)': $($_.Exception.Message)"
        throw
    }
}

# Write-LzLog and ConvertTo-LzTagHashtable are Private helpers by file location, but they are
# also called directly by the orchestration scripts under scripts/ (deploy.ps1, validate.ps1,
# cleanup.ps1) so those scripts can share the same logging and tagging logic as the module
# instead of duplicating it. Export them alongside the Public functions; every other Private
# helper (Test-LzNameLength, Get-LzUniqueSuffix, Test-LzResourceGroupExists) remains internal to
# the module and is only used by other module functions.
$scriptFacingPrivateFunctions = @('Write-LzLog', 'ConvertTo-LzTagHashtable')
$functionsToExport = @($publicFunctions.BaseName) + $scriptFacingPrivateFunctions
Export-ModuleMember -Function $functionsToExport
