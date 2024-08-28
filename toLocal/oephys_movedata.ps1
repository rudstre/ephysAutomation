# Load configuration from JSON
$configPath = "$PSScriptRoot\oephys_config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Define constants from the config file
$hostAddress = $config.Config.Host
$port = $config.Config.Port
$destinationPath = "C:\Path\To\Destination"  # Path where you want to move recordings

# Function to get the recording information from the API
function Get-RecordingInfo {
    $url = "http://$($hostAddress):$($port)/api/recording"
    $response = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json"
    return $response
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

foreach ($node in $recordNodes) {
    $recordNodeDirectory = $node.parent_directory
    $baseText = $recordingInfo.base_text

    # Construct the path to the recording directory
    $recordingDir = Join-Path -Path $recordNodeDirectory -ChildPath "$baseText\Record Node $($node.node_id)"

    # Get all experiment directories
    $experimentDirs = Get-ChildItem -Path $recordingDir -Directory -Filter "experiment*"

    if ($experimentDirs.Count -gt 1) {
        # Sort experiments by creation time to identify the second most recent
        $experimentDirs = $experimentDirs | Sort-Object LastWriteTime -Descending
        $secondMostRecentExperiment = $experimentDirs[1]

        # Check if files are still in use
        if (-not (Test-FilesInUse -path $secondMostRecentExperiment.FullName)) {
            # Move the second most recent experiment directory to the destination
            $targetPath = Join-Path -Path $destinationPath -ChildPath $secondMostRecentExperiment.Name
            Move-Item -Path $secondMostRecentExperiment.FullName -Destination $targetPath -Force
            Write-Host "Moved experiment directory from $($secondMostRecentExperiment.FullName) to $targetPath."
        } else {
            Write-Host "Files in $($secondMostRecentExperiment.FullName) are still in use. Will retry later."
        }
    } else {
        Write-Host "No experiments to move in $recordingDir."
    }
}
