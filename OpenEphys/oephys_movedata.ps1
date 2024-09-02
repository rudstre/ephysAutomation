# Import common functions
. "$env:OEPHYS_SCRIPT_PATH\common\oephys_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\notifications_common.ps1"

# Retrieve the full save path from the user's local config
$fullSavePath = $userInfo.FullSavePath

# Ensure the full save path exists
if (-not $fullSavePath -or -not (Test-Path -Path $fullSavePath)) {
    Write-Host "Full save path $fullSavePath does not exist. Please check your configuration."
    exit
}

# Retrieve Open Ephys parent directory and record nodes info
$recordingInfo = Get-RecordingInfo
$parentDirectory = $recordingInfo.parent_directory
$recordNodes = $recordingInfo.record_nodes

# Move recordings from each Record Node's folder
foreach ($node in $recordNodes) {
    $nodeId = $node.node_id
    $nodeParentDirectory = $node.parent_directory
    $baseText = $recordingInfo.base_text

    # Construct the path to the base folder where recordings are saved
    $nodeBaseFolder = Join-Path -Path $nodeParentDirectory -ChildPath $baseText

    # Check if the node base folder exists
    if (-not (Test-Path -Path $nodeBaseFolder)) {
        Write-Host "Recording directory does not exist: $nodeBaseFolder"
        continue
    }

    # Locate the Record Node directory (e.g., "Record Node 101")
    $recordNodeFolders = Get-ChildItem -Path $nodeBaseFolder -Directory | Where-Object { $_.Name -like "Record Node *" }

    foreach ($recordNodeFolder in $recordNodeFolders) {
        # Locate the experiment folders (e.g., "experiment2")
        $experimentFolders = Get-ChildItem -Path $recordNodeFolder.FullName -Directory | Where-Object { $_.Name -like "experiment*" } | Sort-Object CreationTime -Descending

        # Ensure at least one experiment folder exists
        if ($experimentFolders.Count -lt 1) {
            Write-Host "No experiment folders found in: $($recordNodeFolder.FullName)"
            continue
        }

        # Get the most recent experiment folder
        $latestExperimentFolder = $experimentFolders[0]

        # Find all recordings within the latest experiment folder
        $recordingFolders = Get-ChildItem -Path $latestExperimentFolder.FullName -Directory | Where-Object { $_.Name -like "recording*" } | Sort-Object CreationTime -Descending

        # Ensure at least one recording folder exists
        if ($recordingFolders.Count -lt 1) {
            Write-Host "No recording folders found in: $($latestExperimentFolder.FullName)"
            continue
        }

        # Move all but the newest recording folder to the destination path
        for ($i = 1; $i -lt $recordingFolders.Count; $i++) {
            $recordingFolder = $recordingFolders[$i]
            $destinationPath = Join-Path -Path $fullSavePath -ChildPath "$baseText\$($recordNodeFolder.Name)\$($latestExperimentFolder.Name)\$($recordingFolder.Name)"

            # Ensure the destination path exists
            if (-not (Test-Path -Path $destinationPath)) {
                New-Item -ItemType Directory -Path $destinationPath -Force
            }

            # Properly escape the path for -like usage
            $escapedFolderPath = $recordingFolder.FullName -replace '\\', '\\\\'

            # Check if files are in use before moving
            $filesInUse = Get-Process | Where-Object { $_.Modules -like "*$escapedFolderPath*" }
            if ($filesInUse) {
                Write-Host "Files in use for $($recordingFolder.FullName). Skipping this folder."
                continue
            }

            Write-Host "Moving files from $($recordingFolder.FullName) to $destinationPath"

            # Use robocopy to move the directory
            Start-Process -NoNewWindow -FilePath "robocopy" -ArgumentList @(
                """$($recordingFolder.FullName)""",  # Correct source directory
                """$($destinationPath)""",           # Correct destination directory
                "*.*",                               # Copy all files
                "/MOV",                              # Move files instead of copying
                "/E",                                # Copy subdirectories, including empty ones
                "/R:3",                              # Retry 3 times on failed copies
                "/W:5"                               # Wait 5 seconds between retries
            ) -Wait
        }
    }
}

Write-Host "Data move operation completed."
