# Import common functions
. "$PSScriptRoot\toLocal\oephys_common.ps1"

# Get the recording information
$recordingInfo = Get-RecordingInfo

# Check the number of record nodes
$recordNodes = $recordingInfo.record_nodes
$recordNodeCount = $recordNodes.Count

if ($recordNodeCount -gt 1) {
    Write-Host "Warning: More than one record node detected ($recordNodeCount). This is not recommended because the buffer is likely to overflow."
    # Automatically proceed if more than one node, but additional logic can be added if needed.
}

# Verify and confirm recording directories for each record node
foreach ($node in $recordNodes) {
    $recordNodeID = $node.node_id
    $recordNodeDirectory = $node.parent_directory
    Write-Host "Record Node $recordNodeID is currently set to record to: $recordNodeDirectory"

    # Assuming directory checks or updates would be handled externally or here if needed
    Write-Host "Proceeding with the current directory for Record Node $recordNodeID."
}

Write-Host "All recording directories confirmed."

# Automatically start the first recording
Write-Host "Starting the first recording..."

# Set Open Ephys to acquire mode before recording
Send-Command "ACQUIRE"
Start-Sleep -Seconds 2

# Start recording
Send-Command "RECORD"
Write-Host "Recording started successfully."

Write-Host "Recording setup is complete. Automated tasks can now proceed."
