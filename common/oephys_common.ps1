# Load configuration from Open Ephys JSON
. "$PSScriptRoot\notifications_common.ps1"
$localScriptPath = "$env:LOCALAPPDATA\OephysScripts"

$oephysConfigPath = "$PSScriptRoot\oephys_config.json"
$oephysConfig = Get-Content -Path $oephysConfigPath | ConvertFrom-Json

# Define constants from the Open Ephys config file
$hostAddress = $oephysConfig.Config.Host
$port = $oephysConfig.Config.Port

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

# Restart recording if stopped
function Restart-Recording {
    Send-Command "RECORD"
    Start-Sleep -Seconds 2

    if (Get-CurrentMode -eq "RECORD") {
        Send-Notification "Recording had stopped but has been successfully restarted."
    } else {
        Send-Notification "Failed to restart recording after it stopped."
    }
}

# Stop recording and run the shutdown script
function Stop-RecordingAndShutdown {
    Send-Command "IDLE"
    & "$PSScriptRoot\oephys_shutdown.ps1"
    Write-Host "Shutdown script executed."
}

# Function to check if Open Ephys is running
function Check-OpenEphysRunning {
    $process = Get-Process -Name "OpenEphys" -ErrorAction SilentlyContinue
    if (-not $process) {
        Send-Notification "Open Ephys has crashed or is not running."
        return $false
    }
    return $true
}

# Check if Open Ephys is still recording
function Check-RecordingStatus {
    $currentMode = Get-CurrentMode
    if ($currentMode -ne "RECORD") {
        Start-Sleep -Seconds 2  # Wait a bit and recheck
        $currentMode = Get-CurrentMode
        if ($currentMode -ne "RECORD") {
            Restart-Recording
            return $false
        }
    }
    return $true
}