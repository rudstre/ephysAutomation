# Load configuration from JSON
$configPath = "$PSScriptRoot\oephys_config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Define constants from the config file
$hostAddress = $config.Config.Host
$port = $config.Config.Port

# Function to send a PUT request to change the mode
function Send-Command {
    param (
        [string]$mode
    )
    $url = "http://$($hostAddress):$($port)/api/status"
    $body = @{ mode = $mode } | ConvertTo-Json
    Invoke-RestMethod -Uri $url -Method Put -Body $body -ContentType "application/json"
}

# Function to get the current mode of Open Ephys
function Get-CurrentMode {
    $url = "http://$($hostAddress):$($port)/api/status"
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    return $response.mode
}

# Function to get the recording information from the API
function Get-RecordingInfo {
    $url = "http://$($hostAddress):$($port)/api/recording"
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    return $response
}

# Main script to handle starting and stopping recordings
$currentMode = Get-CurrentMode

if ($currentMode -eq "RECORD") {
    # If already recording, stop the recording
    Send-Command "ACQUIRE"
    Write-Host "Recording stopped."

    # Immediately start a new recording
    Start-Sleep -Seconds 2
    Send-Command "RECORD"
    Write-Host "New recording started for continuity."
} else {
    # If not recording, start acquisition and then start a new recording
    Send-Command "ACQUIRE"
    Start-Sleep -Seconds 2
    Send-Command "RECORD"
    Write-Host "Acquisition and recording started."
}
