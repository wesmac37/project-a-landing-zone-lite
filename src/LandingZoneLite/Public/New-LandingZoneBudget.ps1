function New-LandingZoneBudget {
    <#
    .SYNOPSIS
        Idempotently creates a low-value Azure Consumption Budget with an email alert placeholder.

    .DESCRIPTION
        Creates a subscription-scoped consumption budget (default $5 USD) using
        New-AzConsumptionBudget, with a notification configured at 80% of the threshold. Budgets
        and alerts are a free Azure Cost Management feature, so this is safe to enable by default.
        The contact email is a placeholder the user must replace with a real address/action group.
        Idempotent: if a budget with the same name already exists, it is returned as-is.

    .PARAMETER BudgetName
        The name of the budget. Defaults to 'budget-lzlite-monthly'.

    .PARAMETER Amount
        The monthly budget amount in USD. Defaults to 5.

    .PARAMETER ContactEmail
        Placeholder email address to notify when the budget threshold is crossed.

    .PARAMETER StartDate
        The budget start date. Defaults to the first day of the current month.

    .EXAMPLE
        New-LandingZoneBudget -BudgetName 'budget-lzlite-monthly' -Amount 5 -ContactEmail 'you@example.com'

    .EXAMPLE
        New-LandingZoneBudget -Amount 10 -ContactEmail 'finops@example.com' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BudgetName = 'budget-lzlite-monthly',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100000)]
        [decimal]$Amount = 5,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContactEmail,

        [Parameter(Mandatory = $false)]
        [datetime]$StartDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0)
    )

    try {
        $existing = Get-AzConsumptionBudget -Name $BudgetName -ErrorAction SilentlyContinue

        if ($existing) {
            Write-LzLog -Message "Budget '$BudgetName' already exists. Skipping creation (idempotent)." -Level Info
            return $existing
        }

        $endDate = $StartDate.AddYears(10)

        $notification = @{
            'Actual_GreaterThan_80_Percent' = @{
                Enabled        = $true
                Operator       = 'GreaterThan'
                Threshold      = 80
                ContactEmail   = @($ContactEmail)
                ThresholdType  = 'Actual'
            }
        }

        if ($PSCmdlet.ShouldProcess($BudgetName, "Create consumption budget of `$$Amount USD")) {
            Write-LzLog -Message "Creating consumption budget '$BudgetName' for `$$Amount USD/month." -Level Info
            $budget = New-AzConsumptionBudget -Name $BudgetName `
                -Amount $Amount `
                -Category 'Cost' `
                -TimeGrain 'Monthly' `
                -StartDate $StartDate `
                -EndDate $endDate `
                -Notification $notification `
                -ErrorAction Stop
            Write-LzLog -Message "Budget '$BudgetName' created successfully." -Level Success
            return $budget
        }
    }
    catch {
        Write-LzLog -Message "Failed to create budget '$BudgetName': $($_.Exception.Message)" -Level Error
        throw
    }
}
