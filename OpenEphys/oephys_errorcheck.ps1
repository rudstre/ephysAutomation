# Import common functions
. "$env:OEPHYS_SCRIPT_PATH\common\oephys_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\tasks_common.ps1"  

# Load the local user configuration
$localUserConfigPath = "$env:OEPHYS_SCRIPT_PATH\configs\user_config.json"
$userConfig = Get-Content -Path $localUserConfigPath | ConvertFrom-Json
$userInfo = $userConfig.UserInfo

# Retrieve the full save path from the user's local config
$fullSavePath = $userInfo.FullSavePath

# Check if the full save path is valid
if (-not $fullSavePath -or -not (Test-Path -Path $fullSavePath)) {
    Write-Host "Full save path $fullSavePath does not exist. Please check your configuration."
    exit
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

# Check if the remote storage drive (Buffer) is connected
function Check-RemoteStorageConnection {
    $drive = Split-Path -Path $fullSavePath -Qualifier
    if (-not (Test-Path $drive)) {
        Send-Notification "Buffer storage is not connected."
        return $false
    }
    return $true
}

# Check storage usage and send alerts based on usage percentage
function Check-StorageUsage {
    param (
        [string]$drivePath,
        [string]$driveName
    )

    $driveLetter = (Split-Path -Qualifier $drivePath).TrimEnd(':')
    $drive = Get-PSDrive -Name $driveLetter -ErrorAction SilentlyContinue

    if ($null -eq $drive) {
        Write-Host "Drive $drivePath does not exist or is not accessible."
        return $false
    }

    $freeSpace = $drive.Free
    $totalSpace = $drive.Used + $drive.Free
    if ($totalSpace -eq 0) {
        Write-Host "Drive $drivePath has no total space detected. Check system settings."
        return $false
    }

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

# Check if scheduled tasks are running
function Check-ScheduledTasks {
    $scheduledTasks = @("Oephys New Chunk Task", "Oephys Move Data Task", "Oephys Check Errors Task")
    foreach ($task in $scheduledTasks) {
        if (-not (Check-ScheduledTask -taskName $task)) {
            Send-Notification "Scheduled task '$task' is not running."
            return $false
        }
    }
    return $true
}

# Check if too many recordings are building up (move data script is keeping up)
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

# Main error checks
if (Check-OpenEphysRunning) {
    if (-not (Check-RecordingStatus)) {
        Write-Host "Attempted to restart recording."
    }
}

if (-not (Check-RemoteStorageConnection)) {
    Write-Host "Buffer storage connection check failed."
}

if (-not (Check-ScheduledTasks)) {
    Write-Host "Scheduled tasks check failed."
}

if (-not (Check-RecordingBuildUp)) {
    Write-Host "Recording build-up check failed."
}

if (-not (Check-StorageUsage -drivePath $env:SystemDrive -driveName "Local")) {
    Write-Host "Local storage check failed."
}

if (-not (Check-StorageUsage -drivePath $fullSavePath -driveName "Buffer")) {
    Write-Host "Buffer storage check failed."
}

Write-Host "Error checking complete."
