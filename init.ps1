# Initialize Open Ephys Environment Setup Script

# Set initial environment variable for script path (before copying files)
$env:OEPHYS_SCRIPT_PATH = "$PSScriptRoot"

# Import common functions
. "$env:OEPHYS_SCRIPT_PATH\common\oephys_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\notifications_common.ps1"
. "$env:OEPHYS_SCRIPT_PATH\common\tasks_common.ps1"

# Define paths
$scriptsPath = "$PSScriptRoot\OpenEphys"  # Source directory to copy files from
$commonPath = "$PSScriptRoot\common"      # Source path for common scripts
$configPath = "$PSScriptRoot\configs"     # Source path for configs
$localScriptPath = "C:\Users\$env:USERNAME\AppData\Local\OephysScripts"

# Ensure local directory exists
if (Test-Path -Path $localScriptPath) {
    Write-Host "Local script path already exists: $localScriptPath"
    Write-Host "Do you want to remove the existing directory and start fresh? (y/n)"
    $response = Read-Host
    if ($response -eq "y") {
        Remove-Item -Path $localScriptPath -Recurse -Force
        New-Item -ItemType Directory -Path $localScriptPath -Force
    } else {
        Write-Host "Exiting script setup."
        exit
    }
} else {
    New-Item -ItemType Directory -Path $localScriptPath -Force
}

# Load user configuration
$userConfigPath = "$env:OEPHYS_SCRIPT_PATH\configs\user_config.json"
$userConfig = Get-Content -Path $userConfigPath | ConvertFrom-Json

# Ensure 'UserInfo' property exists
if (-not $userConfig.PSObject.Properties['UserInfo']) {
    Add-Member -InputObject $userConfig -MemberType NoteProperty -Name 'UserInfo' -Value @()
}

# Function to get or create user info
function Get-OrCreateUserInfo {
    Write-Host "Enter your First Name:"
    $firstName = Read-Host

    Write-Host "Enter your Last Name:"
    $lastName = Read-Host

    # Check if user already exists in the configuration
    $userInfo = $userConfig.UserInfo | Where-Object { $_.FirstName -eq $firstName -and $_.LastName -eq $lastName }

    if (-not $userInfo) {
        Write-Host "No user information found for $firstName $lastName. Creating new user entry..."
        $userInfo = [PSCustomObject]@{
            FirstName = $firstName
            LastName  = $lastName
            UserKey   = ""
            Devices   = @()
            BaseSavePath = ""
            SelectedDevices = @()
        }
        # Add new user to the UserInfo array
        $userConfig.UserInfo += $userInfo
    } else {
        Write-Host "Welcome back, $firstName $lastName! Your user information has been found."
    }

    return $userInfo
}

# Get or create the user info
$userInfo = Get-OrCreateUserInfo

# Check if the user has a Pushover UserKey
if (-not $userInfo.UserKey) {
    Write-Host "No Pushover user key found in your configuration."
    Write-Host "Please obtain your Pushover user key by logging into your Pushover account."
    Write-Host "Once obtained, enter your Pushover user key:"
    $userInfo.UserKey = Read-Host
}

# Validate Pushover user key and retrieve devices
$devices = Validate-UserKey -userKey $userInfo.UserKey

# Store the complete device list in the global config
$userInfo.Devices = $devices

# Ensure 'SelectedDevices' property exists on the user info
Ensure-PropertyExists -Object $userInfo -PropertyName 'SelectedDevices' -DefaultValue @()

# If no selected devices, prompt user for selection
if (-not $userInfo.SelectedDevices) {
    Write-Host "No devices selected for notifications. Available devices: $($devices -join ', ')"
    Write-Host "Please select devices to be notified ('all' for all devices):"
    $selectedDevices = Read-Host
    $userInfo.SelectedDevices = $selectedDevices -split ','

    # Save the selected devices in global config
    $userConfig | ConvertTo-Json | Set-Content -Path $userConfigPath
}

# Save selected devices to local config
$localUserConfig = @{
    UserInfo = @{
        FirstName = $userInfo.FirstName
        LastName = $userInfo.LastName
        UserKey = $userInfo.UserKey
        SelectedDevices = $userInfo.SelectedDevices
        FullSavePath = ($userInfo.BaseSavePath + "\" + $projectFolder)
    }
}

$localUserConfig | ConvertTo-Json | Set-Content -Path "$localScriptPath\user_config.json"

# Copy files locally
try {
    # Ensure common and configs directories are created as directories
    New-Item -Path "$localScriptPath\common" -ItemType Directory -Force
    New-Item -Path "$localScriptPath\configs" -ItemType Directory -Force

    Copy-Item -Path "$scriptsPath\*" -Destination "$localScriptPath" -Recurse -Force
    Write-Host "Scripts copied successfully from $scriptsPath to $localScriptPath."

    Copy-Item -Path "$commonPath\*" -Destination "$localScriptPath\common" -Recurse -Force
    Write-Host "Common files copied successfully from $commonPath to $localScriptPath\common."

    Copy-Item -Path "$configPath\*" -Destination "$localScriptPath\configs" -Recurse -Force
    Write-Host "Config files copied successfully from $configPath to $localScriptPath\configs."
} catch {
    Write-Host "Error copying files: $_"
}

# Set environment variable to the new local path after copying
$env:OEPHYS_SCRIPT_PATH = $localScriptPath

Write-Host "All necessary files and notifications directory copied to local storage for resilience against remote storage disconnection."

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
