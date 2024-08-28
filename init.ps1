# Import common functions
. "$PSScriptRoot\common\oephys_common.ps1"
. "$PSScriptRoot\common\notifications_common.ps1"
. "$PSScriptRoot\common\tasks_common.ps1"

# Define paths
$scriptsPath = "$PSScriptRoot\OpenEphys"  # Source directory to copy files from
$commonPath = "$PSScriptRoot\common"  # Source path for notifications directory
$configPath = "$PSScriptRoot\configs"  # Source path for notifications directory


# Function to get or create user info
function Get-OrCreateUserInfo {
    Write-Host "Enter your First Name:"
    $firstName = Read-Host

    Write-Host "Enter your Last Name:"
    $lastName = Read-Host

    # Check if user already exists in the configuration
    $userInfo = $notificationsConfig.UserInfo | Where-Object { $_.FirstName -eq $firstName -and $_.LastName -eq $lastName }

    if (-not $userInfo) {
        Write-Host "No user information found for $firstName $lastName. Creating new user entry..."
        $userInfo = @{
            FirstName = $firstName
            LastName  = $lastName
            UserKey   = ""
            Devices   = @()
            BaseSavePath = ""
        }
        $notificationsConfig.UserInfo += $userInfo
    } else {
        Write-Host "Welcome back, $firstName $lastName! Your user information has been found."
    }

    return $userInfo
}

# Get or create the user info
$userInfo = Get-OrCreateUserInfo

# Check for the base save path in the user's configuration
if (-not $userInfo.BaseSavePath) {
    Write-Host "No base save path found in your configuration."
    Write-Host "Please specify a general base path on the Buffer storage where all Open Ephys data should be moved after recording."
    Write-Host "Note: This path should NOT be project-specific. You will choose a project-specific folder shortly."
    $userInfo.BaseSavePath = Read-Host
} else {
    Write-Host "Current base save path for moving data: $($userInfo.BaseSavePath)"
    Write-Host "This path should be a general location for storing all Open Ephys data."
    Write-Host "Do you want to keep this base save path? (y/n)"
    $response = Read-Host
    if ($response -ne "y") {
        Write-Host "Please specify a new general base save path on the Buffer storage:"
        $userInfo.BaseSavePath = Read-Host
    }
}

# Ask for the project-specific folder name within the base save path
Write-Host "Enter the project-specific folder name to organize the data within the base save path:"
$projectFolder = Read-Host
$oephysConfig.Config.ProjectFolder = $projectFolder
$oephysConfig | ConvertTo-Json | Set-Content -Path $oephysConfigPath

# Ensure local directory exists
if (-not (Test-Path -Path $localScriptPath)) {
    New-Item -ItemType Directory -Path $localScriptPath
}

# Run oephys_startup.ps1 to set up the recording environment
Write-Host "Running startup script to initialize Open Ephys recording setup..."
& "$PSScriptRoot\oephys_startup.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Startup script failed. Please check the setup and try again."
    exit
}

# Copy files locally
Copy-Item -Path "$scriptsPath\*" -Destination $localScriptPath -Recurse -Force
Copy-Item -Path "$commonPath" -Destination $localScriptPath -Recurse -Force
Copy-Item -Path "$configPath" -Destination $localScriptPath -Recurse -Force

Write-Host "All necessary files and notifications directory copied to local storage for resilience against remote storage disconnection."

# Save the updated notifications config to file
$notificationsConfig | ConvertTo-Json | Set-Content -Path $notificationsConfigPath

# Prompt user to enter intervals for scheduled tasks
function Get-IntervalInput {
    param (
        [string]$taskDescription
    )
    
    do {
        Write-Host "Enter the interval for $taskDescription (e.g., 60s for 60 seconds, 2m for 2 minutes):"
        $input = Read-Host
        
        if ($input -match '^\d+[sm]$') {
            if ($input -like '*s') {
                return "PT$($input -replace 's','')S"
            } elseif ($input -like '*m') {
                return "PT$($input -replace 'm','')M"
            }
        } else {
            Write-Host "Invalid input. Please enter a valid interval."
        }
    } while ($true)
}

# Get intervals from user
$chunkInterval = Get-IntervalInput -taskDescription "starting/stopping recording (new chunk)"
$moveDataInterval = Get-IntervalInput -taskDescription "moving data"
$checkErrorsInterval = Get-IntervalInput -taskDescription "checking for errors"

# Paths to local copies of your scripts
$oephysNewChunkPath = "$localScriptPath\oephys_newchunk.ps1"
$oephysMoveDataPath = "$localScriptPath\oephys_movedata.ps1"
$oephysCheckErrorsPath = "$localScriptPath\oephys_errorcheck.ps1"

# Create scheduled tasks
Create-ScheduledTask -taskName "Oephys New Chunk Task" -scriptPath $oephysNewChunkPath -interval $chunkInterval
Create-ScheduledTask -taskName "Oephys Move Data Task" -scriptPath $oephysMoveDataPath -interval $moveDataInterval
Create-ScheduledTask -taskName "Oephys Check Errors Task" -scriptPath $oephysCheckErrorsPath -interval $checkErrorsInterval

Write-Host "Scheduled tasks created successfully."
Write-Host "Pushover user key and device preferences saved. Other scripts will use this information for sending notifications."
