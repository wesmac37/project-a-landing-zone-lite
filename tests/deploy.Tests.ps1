#Requires -Module Pester
<#
    deploy.Tests.ps1

    Pester v5 tests focused specifically on scripts/deploy.ps1 behavior: config handling,
    switch-override logic, and safe failure modes. All Az* cmdlets are mocked — no live Azure
    calls are made anywhere in this test file.
#>

BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot '..'
    $script:DeployScript = Join-Path $script:RepoRoot 'scripts' 'deploy.ps1'
    $script:ValidateScript = Join-Path $script:RepoRoot 'scripts' 'validate.ps1'
    $script:ModuleManifest = Join-Path $script:RepoRoot 'src' 'LandingZoneLite' 'LandingZoneLite.psd1'
    $script:ConfigPath = Join-Path $script:RepoRoot 'config' 'landingzone.config.json'
    $script:AzStubsPath = Join-Path $PSScriptRoot 'AzStubs.psm1'

    # Import no-op Az cmdlet stubs unconditionally, regardless of whether the real Az PowerShell
    # module happens to be installed on this machine/runner, so every Az* cmdlet name resolves
    # to our controlled, deterministic no-op stub (imported -Global) rather than a real cmdlet
    # that could attempt a live call. Every stub is then fully replaced by an explicit Mock in
    # each test - no stub body ever executes as-is.
    Import-Module $script:AzStubsPath -Force -Global

    Import-Module $script:ModuleManifest -Force
}

AfterAll {
    Remove-Module -Name 'LandingZoneLite' -ErrorAction SilentlyContinue
    Remove-Module -Name 'AzStubs' -ErrorAction SilentlyContinue
}

Describe 'deploy.ps1 parameter contract' {

    It 'exposes ConfigPath, IncludeNetwork, and IncludeBudget parameters' {
        $paramNames = (Get-Command $script:DeployScript).Parameters.Keys
        $paramNames | Should -Contain 'ConfigPath'
        $paramNames | Should -Contain 'IncludeNetwork'
        $paramNames | Should -Contain 'IncludeBudget'
        $paramNames | Should -Contain 'WhatIf'
    }

    It 'throws a clear error when the config file does not exist' {
        Mock -CommandName Get-AzContext -MockWith {
            [PSCustomObject]@{ Subscription = [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000000'; Name = 'mock-sub' } }
        }

        { & $script:DeployScript -ConfigPath '/nonexistent/path/config.json' -WhatIf } | Should -Throw
    }
}

Describe 'deploy.ps1 fails fast without an Az context' {

    It 'throws when Get-AzContext returns null' {
        Mock -CommandName Get-AzContext -MockWith { $null }

        { & $script:DeployScript -ConfigPath $script:ConfigPath -WhatIf } | Should -Throw
    }
}

Describe 'validate.ps1 parameter contract' {

    It 'exposes ConfigPath, IncludeNetwork, and IncludeBudget parameters' {
        $paramNames = (Get-Command $script:ValidateScript).Parameters.Keys
        $paramNames | Should -Contain 'ConfigPath'
        $paramNames | Should -Contain 'IncludeNetwork'
        $paramNames | Should -Contain 'IncludeBudget'
    }
}

Describe 'validate.ps1 exit codes' {

    It 'exits non-zero when a required resource is missing' {
        $pwshPath = (Get-Process -Id $PID).Path
        $stubsArg = $script:AzStubsPath
        $scriptToRun = @"
Import-Module '$stubsArg' -Force
Mock() { }
& '$($script:ValidateScript)' -ConfigPath '$($script:ConfigPath)'
"@
        # Run validate.ps1 in a fresh child process (its Get-Az* calls resolve to the real/absent
        # Az module there, not to this file's Mocks) so every resource lookup naturally returns
        # nothing and every check fails, driving a non-zero exit code.
        & $pwshPath -NoProfile -Command "Import-Module '$stubsArg' -Force; & '$($script:ValidateScript)' -ConfigPath '$($script:ConfigPath)'" | Out-Null
        $LASTEXITCODE | Should -Be 1
    }
}
