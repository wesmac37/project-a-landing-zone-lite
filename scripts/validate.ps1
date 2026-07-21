#Requires -Version 7.0
<#
.SYNOPSIS
    Validates that the LandingZoneLite deployment matches the expected end state.

.DESCRIPTION
    Calls Get-LandingZoneStatus to survey resource groups, storage account configuration, Key
    Vault configuration, policy assignment, budget, and (optionally) network resources. Prints a
    PASS/FAIL markdown table to the console and writes the same report to
    ../logs/validation-report-<timestamp>.md. Exits with a non-zero exit code if any check fails,
    making this script suitable for use as a CI gate.

.PARAMETER ConfigPath
    Path to the landingzone.config.json file. Defaults to ../config/landingzone.config.json
    relative to this script.

.PARAMETER IncludeNetwork
    Switch indicating that network resources were deployed and should be validated as present.
    If not supplied, network checks are reported as Skipped.

.PARAMETER IncludeBudget
    Switch indicating that a budget was deployed and should be validated as present. Defaults to
    the config file's includeBudget value unless explicitly overridden.

.EXAMPLE
    ./validate.ps1
    Validates a plain deployment (no network, budget per config).

.EXAMPLE
    ./validate.ps1 -IncludeNetwork
    Validates a deployment that included the optional spoke network.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..' 'config' 'landingzone.config.json'),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNetwork,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeBudget
)

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..' 'src' 'LandingZoneLite' 'LandingZoneLite.psd1'
Import-Module $modulePath -Force -ErrorAction Stop

if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found at '$ConfigPath'."
}
$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

$effectiveIncludeNetwork = $IncludeNetwork.IsPresent -or [bool]$config.includeNetwork
$effectiveIncludeBudget = if ($PSBoundParameters.ContainsKey('IncludeBudget')) { $IncludeBudget.IsPresent } else { [bool]$config.includeBudget }

$mgmtRg = 'rg-lzlite-mgmt-eastus'
$dataRg = 'rg-lzlite-data-eastus'
$networkRg = 'rg-lzlite-network-eastus'
$storageAccountName = "stlzlite$($config.uniqueSuffix)"
$keyVaultName = "kv-lzlite-$($config.uniqueSuffix)"

$statusResults = Get-LandingZoneStatus -ManagementRg $mgmtRg `
    -DataRg $dataRg `
    -NetworkRg $networkRg `
    -StorageAccountName $storageAccountName `
    -KeyVaultName $keyVaultName `
    -BudgetName 'budget-lzlite-monthly' `
    -PolicyAssignmentName 'inherit-tag-lzlite' `
    -IncludeNetwork:$effectiveIncludeNetwork `
    -IncludeBudget:$effectiveIncludeBudget

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDirectory = Join-Path $PSScriptRoot '..' 'logs'
if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
$reportPath = Join-Path $logDirectory "validation-report-$timestamp.md"

$passCount = @($statusResults | Where-Object { $_.Status -eq 'Pass' }).Count
$failCount = @($statusResults | Where-Object { $_.Status -eq 'Fail' }).Count
$skippedCount = @($statusResults | Where-Object { $_.Status -eq 'Skipped' }).Count

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add('# LandingZoneLite Validation Report')
$reportLines.Add('')
$reportLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') (local)")
$reportLines.Add('')
$reportLines.Add("Summary: **$passCount passed**, **$failCount failed**, **$skippedCount skipped**")
$reportLines.Add('')
$reportLines.Add('| Component | Target | Status | Detail |')
$reportLines.Add('|---|---|---|---|')

foreach ($result in $statusResults) {
    $statusIcon = switch ($result.Status) {
        'Pass'    { 'PASS' }
        'Fail'    { 'FAIL' }
        'Skipped' { 'SKIPPED' }
        default   { $result.Status }
    }
    $reportLines.Add("| $($result.Component) | $($result.Target) | $statusIcon | $($result.Detail) |")
}

$reportLines.Add('')
if ($failCount -eq 0) {
    $reportLines.Add('Overall result: **PASS** — no failing checks.')
}
else {
    $reportLines.Add('Overall result: **FAIL** — one or more checks failed. See table above.')
}

$reportContent = $reportLines -join [System.Environment]::NewLine
Set-Content -Path $reportPath -Value $reportContent -Encoding utf8

Write-Host ''
Write-Host '=== LandingZoneLite Validation Report ===' -ForegroundColor Yellow
Write-Host $reportContent
Write-Host ''
Write-Host "Full report written to: $reportPath" -ForegroundColor Cyan

if ($failCount -gt 0) {
    Write-Host "Validation FAILED ($failCount check(s) failed)." -ForegroundColor Red
    exit 1
}
else {
    Write-Host 'Validation PASSED.' -ForegroundColor Green
    exit 0
}
