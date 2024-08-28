# Load configuration from JSON
$configPath = "$PSScriptRoot\oephys_config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Define constants from the config file
$hostAddress = $config.Config.Host
$port = $config.Config.Port

# Function to get the recording information from the API
function Get-RecordingInfo {
    $url = "http://$($hostAddress):$($port)/api/recording"
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    return $response
}

# Get the recording information
$recordingInfo = Get-RecordingInfo

# Check the number of record nodes
$recordNodes = $recordingInfo.record_nodes
$recordNodeCount = $recordNodes.Count

if ($recordNodeCount -gt 1) {
    Write-Host "Warning: More than one record node detected ($recordNodeCount). This is not recommended because the buffer is likely to overflow."
    # Automatically proceed if more than one node, but you could add logic to handle differently if needed.
}

# Verify and confirm recording directories for each record node
foreach ($node in $recordNodes) {
    $recordNodeID = $node.node_id
    $recordNodeDirectory = $node.parent_directory
    Write-Host "Record Node $recordNodeID is currently set to record to: $recordNodeDirectory"
    
    # If needed, this could be updated automatically or prompt the user via another interface to update settings
    Write-Host "Proceeding with the current directory for Record Node $recordNodeID."
}

Write-Host "All recording directories confirmed."

# Automatically start the first recording
Write-Host "Starting the first recording..."

# Set Open Ephys to acquire mode before recording
Invoke-RestMethod -Uri "http://$($hostAddress):$($port)/api/status" -Method Put -Body (@{mode = "ACQUIRE"} | ConvertTo-Json) -ContentType "application/json"
Start-Sleep -Seconds 2

# Start recording
Invoke-RestMethod -Uri "http://$($hostAddress):$($port)/api/status" -Method Put -Body (@{mode = "RECORD"} | ConvertTo-Json) -ContentType "application/json"
Write-Host "Recording started successfully."

Write-Host "Recording setup is complete. Automated tasks can now proceed."
