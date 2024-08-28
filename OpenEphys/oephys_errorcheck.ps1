# Import common functions
. "$PSScriptRoot\..\oephys_common.ps1"
. "$PSScriptRoot\..\tasks_common.ps1"  

# Load configuration settings
$baseSavePath = $oephysConfig.Config.BaseSavePath
$projectFolder = $oephysConfig.Config.ProjectFolder
$destinationBasePath = Join-Path -Path $baseSavePath -ChildPath $projectFolder

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
    $drive = Split-Path -Path $destinationBasePath -Qualifier
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

# Check if scheduled tasks are running
function Check-ScheduledTasks {
    $scheduledTasks = @("Oephys New Chunk Task", "Oephys Move Data Task", "Oephys Check Errors Task")
    foreach ($task in $scheduledTasks) {
        if (-not Check-ScheduledTask -taskName $task) {
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

if (-not Check-StorageUsage -drivePath $env:SystemDrive -driveName "Local") {
    Write-Host "Local storage check failed."
}

if (-not Check-StorageUsage -drivePath $destinationBasePath -driveName "Buffer") {
    Write-Host "Buffer storage check failed."
}

Write-Host "Error checking complete."
