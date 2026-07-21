@{
    RootModule            = 'LandingZoneLite.psm1'
    ModuleVersion         = '1.0.0'
    GUID                  = 'b7e3f2a0-4c1d-4e9a-9f6a-2d8c6a1e7f3b'
    Author                = 'LandingZoneLite Project'
    CompanyName           = 'Unaffiliated'
    Copyright             = '(c) 2026 LandingZoneLite Project. Licensed under the MIT License.'
    Description           = 'A PowerShell toolkit for deploying a cost-aware Azure landing zone lite foundation: resource groups, tags, RBAC pattern, policy assignment, optional budget, storage account, Key Vault, and optional spoke-ready network. Mirrors Microsoft Cloud Adoption Framework (CAF) landing zone principles at a scale safe for an Azure Free Account.'
    PowerShellVersion     = '7.0'
    RequiredModules       = @()
    FunctionsToExport     = @(
        'New-LandingZoneResourceGroup',
        'Set-LandingZoneTags',
        'New-LandingZoneRoleAssignment',
        'New-LandingZonePolicyAssignment',
        'New-LandingZoneBudget',
        'New-LandingZoneStorageAccount',
        'New-LandingZoneKeyVault',
        'New-LandingZoneNetworkSpoke',
        'Get-LandingZoneStatus',
        'Write-LzLog',
        'ConvertTo-LzTagHashtable'
    )
    CmdletsToExport       = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    PrivateData           = @{
        PSData = @{
            Tags         = @('Azure', 'PowerShell', 'LandingZone', 'Governance', 'IaC', 'DevOps', 'CostManagement')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/example/project-a-landing-zone-lite'
            ReleaseNotes = 'Initial release: resource groups, tagging, RBAC pattern, policy assignment, budget, storage account, Key Vault, optional network spoke, and status/validation reporting.'
        }
    }
}
