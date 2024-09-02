# Import common functions
. "$env:OEPHYS_SCRIPT_PATH\common\oephys_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\notifications_common.ps1"

# Load configuration settings
$recordingInfo = Get-RecordingInfo
$recordNodes = $recordingInfo.record_nodes

# Function to check and warn if multiple record nodes are detected
function Check-MultipleRecordNodes {
    if ($recordNodes.Count -gt 1) {
        Write-Host "Warning: More than one record node detected. This is not recommended as it may cause buffer overflow."
        Write-Host "Do you want to continue with multiple record nodes? (y/n)"
        $response = Read-Host
        if ($response -ne "y") {
            Send-Notification "Startup aborted by user due to multiple record nodes."
            exit
        }
    } else {
        Write-Host "Single record node detected. Proceeding with setup..."
    }
}

# Function to confirm the current recording path
function Confirm-RecordingPath {
    $currentRecordingPath = $recordNodes[0].parent_directory
    Write-Host "Current recording path for Record Node is: $currentRecordingPath"
    Write-Host "Is this the path you want to use for recording? (y/n)"
    $response = Read-Host
    if ($response -ne "y") {
        Write-Host "Please specify the new recording path for data storage:"
        $newPath = Read-Host
        # Update the recording path in Open Ephys (requires API support)
        Set-RecordingPath -newPath $newPath  # Placeholder function, implementation depends on Open Ephys API
        Write-Host "Recording path updated to: $newPath"
    } else {
        Write-Host "Using the existing recording path."
    }
}

# Main startup sequence
Write-Host "Initializing Open Ephys startup..."
Check-MultipleRecordNodes
Confirm-RecordingPath

Write-Host "Open Ephys startup process complete."
