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

Write-Host "Shutdown process completed successfully."
