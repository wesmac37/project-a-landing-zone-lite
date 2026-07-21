#Requires -Module Pester
<#
    LandingZoneLite.Module.Tests.ps1

    Pester v5 unit tests for the LandingZoneLite module's Public and Private functions. All Az*
    cmdlets are mocked — no live Azure calls are made anywhere in this test file.
#>

BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' 'src' 'LandingZoneLite'
    $script:ModuleManifest = Join-Path $script:ModuleRoot 'LandingZoneLite.psd1'
    $script:ConfigPath = Join-Path $PSScriptRoot '..' 'config' 'landingzone.config.json'
    $script:AzStubsPath = Join-Path $PSScriptRoot 'AzStubs.psm1'

    # Import no-op Az cmdlet stubs unconditionally, regardless of whether the real Az PowerShell
    # module happens to be installed on this machine/runner. This guarantees every Az* cmdlet
    # name used by the module resolves to our controlled, deterministic no-op stub (imported
    # -Global, so it wins command resolution over any lazily auto-loaded real Az module) rather
    # than a real cmdlet that could attempt a live call and fail with an authentication error
    # (e.g. 'Run Connect-AzAccount to login.') when a mock isn't perfectly scoped. Every stub is
    # then fully replaced by an explicit Mock in each test - no stub body ever executes as-is.
    Import-Module $script:AzStubsPath -Force -Global

    Import-Module $script:ModuleManifest -Force
}

AfterAll {
    Remove-Module -Name 'LandingZoneLite' -ErrorAction SilentlyContinue
    Remove-Module -Name 'AzStubs' -ErrorAction SilentlyContinue
}

Describe 'LandingZoneLite module manifest' {

    It 'imports successfully and exports the expected public functions' {
        $expectedFunctions = @(
            'New-LandingZoneResourceGroup',
            'Set-LandingZoneTags',
            'New-LandingZoneRoleAssignment',
            'New-LandingZonePolicyAssignment',
            'New-LandingZoneBudget',
            'New-LandingZoneStorageAccount',
            'New-LandingZoneKeyVault',
            'New-LandingZoneNetworkSpoke',
            'Get-LandingZoneStatus'
        )

        $module = Get-Module -Name 'LandingZoneLite'
        $exported = $module.ExportedFunctions.Keys

        foreach ($functionName in $expectedFunctions) {
            $exported | Should -Contain $functionName
        }
    }
}

Describe 'config/landingzone.config.json' {

    BeforeAll {
        $script:ConfigContent = Get-Content -Path $script:ConfigPath -Raw | ConvertFrom-Json
    }

    It 'loads as valid JSON' {
        $script:ConfigContent | Should -Not -BeNullOrEmpty
    }

    It 'has all required top-level keys' {
        $requiredKeys = @(
            'subscriptionId', 'location', 'environment', 'ownerTag', 'costCenterTag',
            'uniqueSuffix', 'budgetAmountUSD', 'includeNetwork', 'includeBudget', 'tagPolicyName'
        )

        foreach ($key in $requiredKeys) {
            ($script:ConfigContent.PSObject.Properties.Name) | Should -Contain $key
        }
    }

    It 'has a numeric budget amount greater than zero' {
        [decimal]$script:ConfigContent.budgetAmountUSD | Should -BeGreaterThan 0
    }
}

Describe 'ConvertTo-LzTagHashtable' {

    It 'merges standard tags and extra tags correctly, with extra tags taking precedence' {
        InModuleScope -ModuleName LandingZoneLite {
            $tags = ConvertTo-LzTagHashtable -Environment 'sandbox' -Owner 'jane@example.com' -CostCenter 'CC-100' -ExtraTags @{ Environment = 'override'; Workload = 'lzlite' }

            $tags['Environment'] | Should -Be 'override'
            $tags['Owner'] | Should -Be 'jane@example.com'
            $tags['CostCenter'] | Should -Be 'CC-100'
            $tags['Project'] | Should -Be 'LandingZoneLite'
            $tags['ManagedBy'] | Should -Be 'PowerShell'
            $tags['Workload'] | Should -Be 'lzlite'
            $tags.ContainsKey('DeployDate') | Should -BeTrue
        }
    }

    It 'produces the standard tag set without extra tags' {
        InModuleScope -ModuleName LandingZoneLite {
            $tags = ConvertTo-LzTagHashtable -Environment 'sandbox' -Owner 'jane@example.com' -CostCenter 'CC-100'

            $tags.Keys.Count | Should -Be 6
            $tags['Environment'] | Should -Be 'sandbox'
        }
    }
}

Describe 'Test-LzNameLength' {

    It 'rejects a storage account name longer than 24 characters' {
        InModuleScope -ModuleName LandingZoneLite {
            $tooLong = 'thisstorageaccountnameiswaytoolong'
            Test-LzNameLength -Name $tooLong -MinLength 3 -MaxLength 24 | Should -BeFalse
        }
    }

    It 'accepts a valid storage account name within range' {
        InModuleScope -ModuleName LandingZoneLite {
            Test-LzNameLength -Name 'stlzliteabc123' -MinLength 3 -MaxLength 24 | Should -BeTrue
        }
    }

    It 'rejects an empty name' {
        InModuleScope -ModuleName LandingZoneLite {
            Test-LzNameLength -Name '' -MinLength 3 -MaxLength 24 | Should -BeFalse
        }
    }
}

Describe 'New-LandingZoneResourceGroup' {

    BeforeEach {
        Mock -CommandName Get-AzResourceGroup -ModuleName LandingZoneLite -MockWith { $null }
        Mock -CommandName New-AzResourceGroup -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ ResourceGroupName = $Name; Location = $Location; Tags = $Tag }
        }
        Mock -CommandName Write-LzLog -ModuleName LandingZoneLite -MockWith { }
    }

    It 'creates a new resource group when it does not already exist' {
        $tags = @{ Environment = 'sandbox' }
        $result = New-LandingZoneResourceGroup -Name 'rg-lzlite-mgmt-eastus' -Location 'eastus' -Tags $tags

        $result.ResourceGroupName | Should -Be 'rg-lzlite-mgmt-eastus'
        Should -Invoke -CommandName New-AzResourceGroup -ModuleName LandingZoneLite -Times 1 -Exactly
    }

    It 'is idempotent and skips creation when the resource group already exists' {
        Mock -CommandName Get-AzResourceGroup -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ ResourceGroupName = 'rg-lzlite-mgmt-eastus'; Location = 'eastus' }
        }

        $tags = @{ Environment = 'sandbox' }
        New-LandingZoneResourceGroup -Name 'rg-lzlite-mgmt-eastus' -Location 'eastus' -Tags $tags | Out-Null

        Should -Invoke -CommandName New-AzResourceGroup -ModuleName LandingZoneLite -Times 0 -Exactly
    }
}

Describe 'New-LandingZonePolicyAssignment' {

    BeforeEach {
        Mock -CommandName Get-AzContext -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ Subscription = [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000000'; Name = 'mock-sub' } }
        }
        Mock -CommandName Get-AzResourceGroup -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ ResourceGroupName = 'rg-lzlite-mgmt-eastus'; ResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lzlite-mgmt-eastus' }
        }
        Mock -CommandName Get-AzPolicyAssignment -ModuleName LandingZoneLite -MockWith { $null }
        Mock -CommandName Get-AzPolicyDefinition -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ Name = '611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f' }
        }
        Mock -CommandName New-AzPolicyAssignment -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ Name = $Name; Scope = $Scope }
        }
        Mock -CommandName Write-LzLog -ModuleName LandingZoneLite -MockWith { }
    }

    It 'calls New-AzPolicyAssignment with the expected assignment name, scope, and tag parameter' {
        New-LandingZonePolicyAssignment -ResourceGroupName 'rg-lzlite-mgmt-eastus' -TagName 'Environment' | Out-Null

        Should -Invoke -CommandName New-AzPolicyAssignment -ModuleName LandingZoneLite -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'inherit-tag-lzlite' -and
            $Scope -eq '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lzlite-mgmt-eastus' -and
            $PolicyParameterObject.tagName.value -eq 'Environment'
        }
    }

    It 'is idempotent and skips assignment when one already exists at scope' {
        Mock -CommandName Get-AzPolicyAssignment -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ Name = 'inherit-tag-lzlite' }
        }

        New-LandingZonePolicyAssignment -ResourceGroupName 'rg-lzlite-mgmt-eastus' -TagName 'Environment' | Out-Null

        Should -Invoke -CommandName New-AzPolicyAssignment -ModuleName LandingZoneLite -Times 0 -Exactly
    }
}

Describe 'New-LandingZoneRoleAssignment' {

    BeforeEach {
        Mock -CommandName Get-AzContext -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ Subscription = [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000000'; Name = 'mock-sub' } }
        }
        Mock -CommandName Get-AzResourceGroup -ModuleName LandingZoneLite -MockWith {
            [PSCustomObject]@{ ResourceGroupName = 'rg-lzlite-mgmt-eastus'; ResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-lzlite-mgmt-eastus' }
        }
        Mock -CommandName Get-AzRoleAssignment -ModuleName LandingZoneLite -MockWith { $null }
        Mock -CommandName Write-LzLog -ModuleName LandingZoneLite -MockWith { }
    }

    It 'does not throw and returns null when the placeholder object ID is invalid in this tenant' {
        Mock -CommandName New-AzRoleAssignment -ModuleName LandingZoneLite -MockWith { throw 'Principal not found in directory' }

        { New-LandingZoneRoleAssignment -ObjectId '11111111-1111-1111-1111-111111111111' -ResourceGroupName 'rg-lzlite-mgmt-eastus' } | Should -Not -Throw
        $result = New-LandingZoneRoleAssignment -ObjectId '11111111-1111-1111-1111-111111111111' -ResourceGroupName 'rg-lzlite-mgmt-eastus'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'deploy.ps1 dry-run (-WhatIf)' {

    BeforeAll {
        $script:DeployScript = Join-Path $PSScriptRoot '..' 'scripts' 'deploy.ps1'

        # deploy.ps1 calls some Az* cmdlets directly (script scope) and calls into the
        # LandingZoneLite module's Public functions, which call other Az* cmdlets from the
        # module's own scope. Both scopes must be mocked for a clean end-to-end dry run.
        $script:DeployMockTargets = @(
            @{ Name = 'Get-AzContext';                     With = { [PSCustomObject]@{ Subscription = [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000000'; Name = 'mock-sub' } } } }
            @{ Name = 'Get-AzResourceProvider';            With = { [PSCustomObject]@{ RegistrationState = 'Registered' } } }
            @{ Name = 'Register-AzResourceProvider';       With = { } }
            @{ Name = 'Get-AzResourceGroup';                With = { $null } }
            @{ Name = 'New-AzResourceGroup';                With = { [PSCustomObject]@{ ResourceGroupName = 'mock-rg'; ResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg' } } }
            @{ Name = 'Get-AzRoleAssignment';               With = { $null } }
            @{ Name = 'New-AzRoleAssignment';               With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzPolicyAssignment';             With = { $null } }
            @{ Name = 'Get-AzPolicyDefinition';             With = { [PSCustomObject]@{ Name = '611c516d-5d1c-4ba1-9dfb-e88f4c78ea5f' } } }
            @{ Name = 'New-AzPolicyAssignment';             With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzConsumptionBudget';            With = { $null } }
            @{ Name = 'New-AzConsumptionBudget';            With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzStorageAccount';               With = { $null } }
            @{ Name = 'New-AzStorageAccount';               With = { [PSCustomObject]@{ Context = 'mock-context' } } }
            @{ Name = 'Get-AzStorageContainer';             With = { $null } }
            @{ Name = 'New-AzStorageContainer';             With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzKeyVault';                     With = { $null } }
            @{ Name = 'New-AzKeyVault';                     With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzKeyVaultSecret';               With = { $null } }
            @{ Name = 'Set-AzKeyVaultSecret';               With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzVirtualNetwork';               With = { $null } }
            @{ Name = 'New-AzVirtualNetwork';               With = { [PSCustomObject]@{} } }
            @{ Name = 'Get-AzNetworkSecurityGroup';         With = { $null } }
            @{ Name = 'New-AzNetworkSecurityGroup';         With = { [PSCustomObject]@{} } }
            @{ Name = 'New-AzVirtualNetworkSubnetConfig';   With = { [PSCustomObject]@{} } }
        )
    }

    It 'executes end-to-end without throwing against mocked Az* cmdlets' {
        foreach ($target in $script:DeployMockTargets) {
            Mock -CommandName $target.Name -MockWith $target.With
            Mock -CommandName $target.Name -ModuleName LandingZoneLite -MockWith $target.With
        }

        # deploy.ps1 itself calls 'Import-Module $modulePath -Force' to guarantee the freshest
        # module code is loaded when run for real. Under test, that self-reimport would discard
        # the LandingZoneLite module instance (and every -ModuleName mock above) that this test
        # just set up, causing later calls to fall through to the real Az cmdlets. Since the
        # module is already loaded (and already mocked) by this file's own top-level BeforeAll,
        # make the script's internal re-import a no-op here.
        Mock -CommandName Import-Module -MockWith { }

        { & $script:DeployScript -ConfigPath $script:ConfigPath -WhatIf } | Should -Not -Throw
    }
}

Describe 'cleanup.ps1 idempotency' {

    BeforeAll {
        $script:CleanupScript = Join-Path $PSScriptRoot '..' 'scripts' 'cleanup.ps1'

        # cleanup.ps1 calls some Az* cmdlets directly (script scope) and calls into the
        # LandingZoneLite module's Public functions, which call other Az* cmdlets from the
        # module's own scope. Both scopes must be mocked for a clean idempotent run.
        $script:CleanupMockTargets = @(
            @{ Name = 'Get-AzResourceLock';           With = { $null } }
            @{ Name = 'Get-AzResourceGroup';           With = { $null } }
            @{ Name = 'Get-AzRoleAssignment';          With = { $null } }
            @{ Name = 'Get-AzPolicyAssignment';        With = { $null } }
            @{ Name = 'Get-AzConsumptionBudget';       With = { $null } }
            @{ Name = 'Get-AzKeyVault';                With = { $null } }
            @{ Name = 'Get-AzStorageAccount';          With = { $null } }
            @{ Name = 'Get-AzVirtualNetwork';          With = { $null } }
            @{ Name = 'Get-AzNetworkSecurityGroup';    With = { $null } }
            @{ Name = 'Remove-AzResourceGroup';        With = { } }
            @{ Name = 'Remove-AzKeyVault';             With = { } }
            @{ Name = 'Remove-AzStorageAccount';       With = { } }
            @{ Name = 'Remove-AzVirtualNetwork';       With = { } }
            @{ Name = 'Remove-AzNetworkSecurityGroup'; With = { } }
            @{ Name = 'Remove-AzPolicyAssignment';     With = { } }
            @{ Name = 'Remove-AzConsumptionBudget';    With = { } }
            @{ Name = 'Remove-AzRoleAssignment';       With = { } }
            @{ Name = 'Remove-AzResourceLock';         With = { } }
        )
    }

    It 'runs without throwing when all resources are already absent' {
        foreach ($target in $script:CleanupMockTargets) {
            Mock -CommandName $target.Name -MockWith $target.With
            Mock -CommandName $target.Name -ModuleName LandingZoneLite -MockWith $target.With
        }

        { & $script:CleanupScript -ConfigPath $script:ConfigPath -Force } | Should -Not -Throw
    }
}
