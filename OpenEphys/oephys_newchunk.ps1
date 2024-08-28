# Import common functions
. "$PSScriptRoot\oephys_common.ps1"

# Main script to handle starting and stopping recordings
$currentMode = Get-CurrentMode

if ($currentMode -eq "RECORD") {
    # If already recording, stop the recording
    Send-Command "ACQUIRE"
    Write-Host "Recording stopped."

    # Immediately start a new recording
    Send-Command "RECORD"
    Write-Host "New recording started for continuity."
} else {
    # If not recording, start acquisition and then start a new recording
    Send-Command "RECORD"
    Write-Host "Acquisition and recording started."
}
