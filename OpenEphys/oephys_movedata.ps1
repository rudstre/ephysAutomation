# Import common functions
. "$PSScriptRoot\..\oephys_common.ps1"
. "$PSScriptRoot\..\notifications_common.ps1"

# Load configuration settings
$baseSavePath = $oephysConfig.Config.BaseSavePath
$projectFolder = $oephysConfig.Config.ProjectFolder  # Assuming this is added to the config during init

# Define the full destination path based on the base save path and project-specific folder
$destinationBasePath = Join-Path -Path $baseSavePath -ChildPath $projectFolder

# Ensure the destination base path exists
if (-not (Test-Path -Path $destinationBasePath)) {
    Write-Host "Creating base path for data storage: $destinationBasePath"
    New-Item -ItemType Directory -Path $destinationBasePath -Force
}

# Function to check if files are in use
function Test-FilesInUse {
    param (
        [string]$path
    )
    try {
        Get-ChildItem -Path $path -Recurse | ForEach-Object {
            $stream = $_.OpenRead()
            $stream.Close()
        }
        return $false
    } catch {
        return $true
    }
}

# Get recording info to find parent directory and base text
$recordingInfo = Get-RecordingInfo
$recordNodes = $recordingInfo.record_nodes
$baseText = $recordingInfo.base_text

# Set up base directory for all recordings if it doesn't exist
$destinationBaseDir = Join-Path -Path $destinationBasePath -ChildPath $baseText
if (-not (Test-Path -Path $destinationBaseDir)) {
    Write-Host "Setting up base directory structure for recordings..."
    New-Item -ItemType Directory -Path $destinationBaseDir -Force

    foreach ($node in $recordNodes) {
        $recordNodeID = $node.node_id
        $recordNodeDestinationDir = Join-Path -Path $destinationBaseDir -ChildPath "Record Node $recordNodeID"

        # Create record node directories in the destination base path
        if (-not (Test-Path -Path $recordNodeDestinationDir)) {
            New-Item -ItemType Directory -Path $recordNodeDestinationDir
        }
    }
    Write-Host "Base directory structure set up successfully."
}

foreach ($node in $recordNodes) {
    $recordNodeDirectory = $node.parent_directory
    $recordNodeID = $node.node_id
    $recordNodeDestinationDir = Join-Path -Path $destinationBaseDir -ChildPath "Record Node $recordNodeID"

    # Construct the path to the recording directory
    $recordingDir = Join-Path -Path $recordNodeDirectory -ChildPath "$baseText\Record Node $recordNodeID"

    # Get all recording directories
    $recordingDirs = Get-ChildItem -Path $recordingDir -Directory -Filter "recording*"

    if ($recordingDirs.Count -gt 1) {
        # Sort recordings by creation time to identify all but the most recent
        $recordingDirs = $recordingDirs | Sort-Object LastWriteTime -Descending
        $recordingsToMove = $recordingDirs[1..$($recordingDirs.Count - 1)]  # All but the newest

        foreach ($recording in $recordingsToMove) {
            # Check if files are still in use
            if (-not (Test-FilesInUse -path $recording.FullName)) {
                # Determine the experiment folder
                $experimentNumber = (Split-Path -Path $recording.FullName -Leaf -Resolve).Split('\')[-2]
                $experimentDestinationDir = Join-Path -Path $recordNodeDestinationDir -ChildPath $experimentNumber

                # Ensure experiment directory exists
                if (-not (Test-Path -Path $experimentDestinationDir)) {
                    New-Item -ItemType Directory -Path $experimentDestinationDir
                }

                # Move recording to the corresponding experiment folder
                $targetPath = Join-Path -Path $experimentDestinationDir -ChildPath $recording.Name
                Move-Item -Path $recording.FullName -Destination $targetPath -Force
                Write-Host "Moved recording directory from $($recording.FullName) to $targetPath."
            } else {
                Write-Host "Files in $($recording.FullName) are still in use. Will retry later."
            }
        }
    } else {
        Write-Host "No recordings to move in $recordingDir."
    }
}
