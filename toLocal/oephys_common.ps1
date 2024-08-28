# oephys_common.ps1

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
