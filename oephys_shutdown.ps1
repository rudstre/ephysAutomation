# Import necessary modules or functions
. "$env:OEPHYS_SCRIPT_PATH\common\oephys_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\notifications_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\tasks_common.ps1"

# Function to safely remove a scheduled task
function Safe-Remove-ScheduledTask {
    param (
        [string]$taskName
    )
    try {
        Remove-ScheduledTask -taskName $taskName
        Write-Host "Scheduled task '$taskName' removed successfully."
    } catch {
        Write-Host "Error removing scheduled task '$taskName': $_"
    }
}

# Remove scheduled tasks
Safe-Remove-ScheduledTask -taskName "Oephys New Chunk Task"
Safe-Remove-ScheduledTask -taskName "Oephys Move Data Task"
Safe-Remove-ScheduledTask -taskName "Oephys Check Errors Task"

# Remove local scripts directory if it exists
if (Test-Path -Path $env:OEPHYS_SCRIPT_PATH) {
    try {
        Remove-Item -Path $env:OEPHYS_SCRIPT_PATH -Recurse -Force
        Write-Host "Local script directory removed."
    } catch {
        Write-Host "Error removing local script directory: $_"
    }
} else {
    Write-Host "Local script directory does not exist."
}

# Remove the environment variable
if ($env:OEPHYS_SCRIPT_PATH) {
    try {
        Remove-Item env:OEPHYS_SCRIPT_PATH
        Write-Host "Environment variable 'OEPHYS_SCRIPT_PATH' removed."
    } catch {
        Write-Host "Error removing environment variable 'OEPHYS_SCRIPT_PATH': $_"
    }
} else {
    Write-Host "Environment variable 'OEPHYS_SCRIPT_PATH' does not exist."
}

Write-Host "Shutdown process completed successfully."
