# Import common functions
. "$PSScriptRoot\common\oephys_common.ps1"
. "$PSScriptRoot\common\tasks_common.ps1"

# Define paths
$localScriptPath = "$env:LOCALAPPDATA\OephysScripts"
$scriptsPath = "$PSScriptRoot\OpenEphys"  # Source directory to copy files from
$commonPath = "$PSScriptRoot\..\common"  # Source path for notifications directory
$configPath = "$PSScriptRoot\..\configs"  # Source path for notifications directory

# Check for the base save path in the Open Ephys config
$baseSavePath = $oephysConfig.Config.BaseSavePath

if (-not $baseSavePath) {
    Write-Host "No base save path found in the configuration."
    Write-Host "Please specify a general base path on the Buffer storage where all Open Ephys data should be moved after recording."
    Write-Host "Note: This path should NOT be project-specific. You will choose a project-specific folder shortly."
    $baseSavePath = Read-Host
    $oephysConfig.Config.BaseSavePath = $baseSavePath
    $oephysConfig | ConvertTo-Json | Set-Content -Path $oephysConfigPath
} else {
    Write-Host "Current base save path for moving data: $baseSavePath"
    Write-Host "This path should be a general location for storing all Open Ephys data."
    Write-Host "Do you want to keep this base save path? (y/n)"
    $response = Read-Host
    if ($response -ne "y") {
        Write-Host "Please specify a new general base save path on the Buffer storage:"
        $baseSavePath = Read-Host
        $oephysConfig.Config.BaseSavePath = $baseSavePath
        $oephysConfig | ConvertTo-Json | Set-Content -Path $oephysConfigPath
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

# Initialize user info from notifications configuration
$userInfo = $notificationsConfig.UserInfo

# Check if user info is already present
if ($userInfo) {
    Write-Host "Welcome back, $($userInfo.FirstName) $($userInfo.LastName)! Your Pushover User Key is already stored."
    $userKey = $userInfo.UserKey
    $previousDevices = $userInfo.Devices
    Write-Host "Previously selected devices: $($previousDevices -join ', ')"
} else {
    # If no user info found, prompt for user details
    Write-Host "Enter your First Name:"
    $firstName = Read-Host

    Write-Host "Enter your Last Name:"
    $lastName = Read-Host

    Write-Host "Enter your Pushover User Key:"
    $userKey = Read-Host

    # Fetch user's devices from Pushover API
    Write-Host "Retrieving your devices from Pushover..."
    $devices = Get-UserDevices

    if ($devices.Count -gt 0) {
        Write-Host "Your devices: $($devices -join ', ')"

        # Prompt user to select devices for notifications or 'all' for all devices
        Write-Host "Enter the devices you want to receive notifications on (comma-separated), or type 'all' for all devices:"
        $selectedDevices = Read-Host

        if ($selectedDevices -eq 'all') {
            $selectedDevicesArray = @('all')
        } else {
            $selectedDevicesArray = $selectedDevices -split '\s*,\s*'
        }

        # Update user info in notifications JSON
        $notificationsConfig.UserInfo = @{
            FirstName = $firstName
            LastName  = $lastName
            UserKey   = $userKey
            Devices   = $selectedDevicesArray
        }

        # Save updated notifications config to file
        $notificationsConfig | ConvertTo-Json | Set-Content -Path $notificationsConfigPath
        Write-Host "User information saved."
    } else {
        Write-Host "Failed to retrieve devices. Please check your Pushover User Key."
        exit
    }
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
