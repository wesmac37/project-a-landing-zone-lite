#Requires -Version 7.0
<#
    AzStubs.psm1

    Lightweight stand-in module that declares no-op stub functions for every Az PowerShell cmdlet
    used by the LandingZoneLite module and scripts. This lets the Pester v5 suite run entirely
    without the real Az PowerShell module installed: Pester's Mock requires the target command to
    exist somewhere in the session, and these stubs satisfy that requirement while every test
    still fully replaces the behavior via `Mock -CommandName ...`. No stub function here ever
    makes (or could make) a live Azure call. If the real Az module IS installed (e.g. in a
    developer's environment), importing this stub module still works safely because tests always
    override behavior with explicit Mocks scoped to the functions under test.
#>

function Get-AzContext { param() }
function Get-AzResourceGroup { param([string]$Name) }
function New-AzResourceGroup { param([string]$Name, [string]$Location, [hashtable]$Tag) }
function Set-AzResourceGroup { param([string]$Name, [hashtable]$Tag) }
function Get-AzResource { param([string]$ResourceId) }
function Set-AzResource { param([string]$ResourceId, [hashtable]$Tag, [switch]$Force) }
function Get-AzResourceLock { param([string]$ResourceGroupName) }
function Remove-AzResourceLock { param([string]$LockId, [switch]$Force) }
function Get-AzResourceProvider { param([string]$ProviderNamespace) }
function Register-AzResourceProvider { param([string]$ProviderNamespace) }

function Get-AzRoleAssignment { param([string]$ObjectId, [string]$RoleDefinitionName, [string]$Scope) }
function New-AzRoleAssignment { param([string]$ObjectId, [string]$RoleDefinitionName, [string]$Scope) }
function Remove-AzRoleAssignment { param([string]$ObjectId, [string]$RoleDefinitionName, [string]$Scope) }

function Get-AzPolicyAssignment { param([string]$Name, [string]$Scope) }
function New-AzPolicyAssignment { param([string]$Name, [string]$Scope, $PolicyDefinition, [hashtable]$PolicyParameterObject) }
function Remove-AzPolicyAssignment { param([string]$Name, [string]$Scope) }
function Get-AzPolicyDefinition { param([string]$Id) }

function Get-AzConsumptionBudget { param([string]$Name) }
function New-AzConsumptionBudget { param([string]$Name, [decimal]$Amount, [string]$Category, [string]$TimeGrain, [datetime]$StartDate, [datetime]$EndDate, [hashtable]$Notification) }
function Remove-AzConsumptionBudget { param([string]$Name) }

function Get-AzStorageAccount { param([string]$ResourceGroupName, [string]$Name) }
function New-AzStorageAccount { param([string]$ResourceGroupName, [string]$Name, [string]$Location, [string]$SkuName, [string]$Kind, [string]$MinimumTlsVersion, [bool]$EnableHttpsTrafficOnly, [bool]$AllowBlobPublicAccess, [hashtable]$Tag) }
function Remove-AzStorageAccount { param([string]$ResourceGroupName, [string]$Name, [switch]$Force) }
function Get-AzStorageContainer { param([string]$Name, $Context) }
function New-AzStorageContainer { param([string]$Name, $Context, [string]$Permission) }

function Get-AzKeyVault { param([string]$ResourceGroupName, [string]$VaultName) }
function New-AzKeyVault { param([string]$ResourceGroupName, [string]$VaultName, [string]$Location, [bool]$EnableRbacAuthorization, [bool]$EnableSoftDelete, [int]$SoftDeleteRetentionInDays, [hashtable]$Tag) }
function Remove-AzKeyVault { param([string]$ResourceGroupName, [string]$VaultName, [string]$Location, [switch]$InRemovedState, [switch]$Force) }
function Get-AzKeyVaultSecret { param([string]$VaultName, [string]$Name) }
function Set-AzKeyVaultSecret { param([string]$VaultName, [string]$Name, $SecretValue) }

function Get-AzVirtualNetwork { param([string]$ResourceGroupName, [string]$Name) }
function New-AzVirtualNetwork { param([string]$ResourceGroupName, [string]$Name, [string]$Location, [string]$AddressPrefix, $Subnet, [hashtable]$Tag) }
function Remove-AzVirtualNetwork { param([string]$ResourceGroupName, [string]$Name, [switch]$Force) }
function New-AzVirtualNetworkSubnetConfig { param([string]$Name, [string]$AddressPrefix, $NetworkSecurityGroup) }
function Get-AzNetworkSecurityGroup { param([string]$ResourceGroupName, [string]$Name) }
function New-AzNetworkSecurityGroup { param([string]$ResourceGroupName, [string]$Name, [string]$Location, [hashtable]$Tag) }
function Remove-AzNetworkSecurityGroup { param([string]$ResourceGroupName, [string]$Name, [switch]$Force) }

Export-ModuleMember -Function *
