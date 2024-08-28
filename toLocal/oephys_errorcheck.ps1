# Import common functions
. "$PSScriptRoot\oephys_common.ps1"

# Define the path for local and remote storage
$localDriveLetter = "C:"  # Adjust this if the local storage is on a different drive
$remoteDrivePath = "\\RemoteStoragePath"  # Replace with the actual network path for Buffer
$shutdownScriptPath = "$PSScriptRoot\oephys_shutdown.ps1"  # Path to the shutdown script

# Pushover API credentials from config
$userKey = $config.UserInfo.UserKey
$apiToken = "your_api_token_here"
$devices = $config.UserInfo.Devices -join ','

# Function to send Pushover notification
function Send-Notification {
    param (
        [string]$message
    )
    Invoke-RestMethod -Uri "https://api.pushover.net/1/messages.json" -Method Post -Body @{
        token = $apiToken
        user = $userKey
        device = $devices
        message = $message
    }
}

# Check if Open Ephys is running
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
        Write-Host "Recording has stopped. Attempting to restart..."
        Restart-Recording
        return $false
    }
    return $true
}

# Restart recording if stopped
function Restart-Recording {
    Send-Command "ACQUIRE"
    Start-Sleep -Seconds 2
    Send-Command "RECORD"
    Start-Sleep -Seconds 2

    if (Get-CurrentMode -eq "RECORD") {
        Send-Notification "Recording had stopped but has been successfully restarted."
    } else {
        Send-Notification "Failed to restart recording after it stopped."
    }
}

# Common function to check storage space and send alerts based on usage percentage
function Check-StorageUsage {
    param (
        [string]$drivePath,
        [string]$driveName
    )

    $drive = Get-PSDrive -Name (Split-Path -Qualifier $drivePath)
    $freeSpace = $drive.Free
    $totalSpace = $drive.Used + $drive.Free
    $usedPercentage = [math]::Round((($totalSpace - $freeSpace) / $totalSpace) * 100, 2)

    if ($usedPercentage -ge 75 -and $usedPercentage -lt 85) {
        Send-Notification "$driveName storage usage at 75%."
    } elseif ($usedPercentage -ge 85 -and $usedPercentage -lt 90) {
        Send-Notification "$driveName storage usage at 85%."
    } elseif ($usedPercentage -ge 90 -and $usedPercentage -lt 95) {
        Send-Notification "$driveName storage usage at 90%."
    } elseif ($usedPercentage -ge 95) {
        Send-Notification "$driveName storage usage at 95%. Stopping recording and shutting down to prevent data loss."
        Stop-RecordingAndShutdown
        return $false
    }
    return $true
}

# Stop recording and run the shutdown script
function Stop-RecordingAndShutdown {
    Send-Command "IDLE"
    Write-Host "Recording stopped due to critical storage usage."

    & $shutdownScriptPath
    Write-Host "Shutdown script executed."
}

# Check if the remote storage drive is connected
function Check-RemoteStorageConnection {
    if (-not (Test-Path $remoteDrivePath)) {
        Send-Notification "Buffer storage is not connected."
        return $false
    }
    return $true
}

# Check if the other scheduled scripts are running
function Check-ScheduledTasks {
    $scheduledTasks = @("Oephys New Chunk Task", "Oephys Move Data Task", "Oephys Check Errors Task")
    foreach ($task in $scheduledTasks) {
        if (-not (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue)) {
            Send-Notification "Scheduled task '$task' is not running."
            return $false
        }
    }
    return $true
}

# Check if too many recordings are building up
function Check-RecordingBuildUp {
    $recordingInfo = Get-RecordingInfo
    $recordNodes = $recordingInfo.record_nodes

    foreach ($node in $recordNodes) {
        $recordNodeDirectory = $node.parent_directory
        $recordings = Get-ChildItem -Path $recordNodeDirectory -Recurse -Directory -Filter "recording*"
        if ($recordings.Count -gt 10) {  # Example threshold, adjust as needed
            Send-Notification "Too many recordings are building up in $recordNodeDirectory. Move data script may not be keeping up."
            return $false
        }
    }
    return $true
}

# Main check functions
if (Check-OpenEphysRunning) {
    if (-not Check-RecordingStatus) {
        Write-Host "Attempted to restart recording."
    }
}

if (-not Check-RemoteStorageConnection) {
    Write-Host "Buffer storage connection check failed."
}

if (-not Check-ScheduledTasks) {
    Write-Host "Scheduled tasks check failed."
}

if (-not Check-RecordingBuildUp) {
    Write-Host "Recording build-up check failed."
}

if (-not Check-StorageUsage -drivePath $localDriveLetter -driveName "Local") {
    Write-Host "Local storage check failed."
}

if (-not Check-StorageUsage -drivePath $remoteDrivePath -driveName "Buffer") {
    Write-Host "Buffer storage check failed."
}

Write-Host "Error checking complete."
