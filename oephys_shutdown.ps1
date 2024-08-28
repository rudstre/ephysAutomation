# Import common functions
. "$PSScriptRoot\common\oephys_common.ps1"
. "$PSScriptRoot\common\tasks_common.ps1"

# Remove scheduled tasks
Remove-ScheduledTask -taskName "Oephys New Chunk Task"
Remove-ScheduledTask -taskName "Oephys Move Data Task"
Remove-ScheduledTask -taskName "Oephys Check Errors Task"

# Clean up local files and folders
if (Test-Path -Path $localScriptPath) {
    Remove-Item -Path $localScriptPath -Recurse -Force
    Write-Host "Local scripts and files removed successfully."
} else {
    Write-Host "Local script directory not found. Nothing to remove."
}

Write-Host "Shutdown script completed."
