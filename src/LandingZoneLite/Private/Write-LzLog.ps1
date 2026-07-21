function Write-LzLog {
    <#
    .SYNOPSIS
        Writes a timestamped, level-tagged log message to the console and optionally to a log file.

    .DESCRIPTION
        Internal logging helper used throughout the LandingZoneLite module. Emits consistent,
        timestamped output so that deploy/validate/cleanup script logs are easy to read and grep.
        When -LogPath is supplied, the same message is appended to the specified file.

    .PARAMETER Message
        The text of the log message.

    .PARAMETER Level
        The severity level of the message. One of Info, Warning, Error, Success. Defaults to Info.

    .PARAMETER LogPath
        Optional path to a log file. If supplied, the message is appended to this file as well as
        written to the console.

    .EXAMPLE
        Write-LzLog -Message "Starting deployment" -Level Info

    .EXAMPLE
        Write-LzLog -Message "Resource group created" -Level Success -LogPath 'C:\logs\deploy.log'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [string]$LogPath
    )

    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $formatted = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'Info'    { Write-Host $formatted -ForegroundColor Cyan }
        'Warning' { Write-Warning $formatted }
        'Error'   { Write-Host $formatted -ForegroundColor Red }
        'Success' { Write-Host $formatted -ForegroundColor Green }
        default   { Write-Host $formatted }
    }

    if ($LogPath) {
        try {
            $logDirectory = Split-Path -Path $LogPath -Parent
            if ($logDirectory -and -not (Test-Path -Path $logDirectory)) {
                New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
            }
            Add-Content -Path $LogPath -Value $formatted -ErrorAction Stop
        }
        catch {
            Write-Warning "Write-LzLog: failed to write to log file '$LogPath': $($_.Exception.Message)"
        }
    }
}
