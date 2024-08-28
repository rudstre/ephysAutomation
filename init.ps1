# Load configuration from JSON
$configPath = "$PSScriptRoot\toLocal\oephys_config.json"
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Define constants from the config file
$hostAddress = $config.Config.Host
$port = $config.Config.Port
$localScriptPath = "$env:LOCALAPPDATA\OephysScripts"
$sourceDirectory = "$PSScriptRoot\toLocal"  # Source directory to copy files from

# Ensure local directory exists
if (-not (Test-Path -Path $localScriptPath)) {
    New-Item -ItemType Directory -Path $localScriptPath
}

# Run oephys_startup.ps1 to set up recording environment
Write-Host "Running startup script to initialize Open Ephys recording setup..."
& "$PSScriptRoot\oephys_startup.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Startup script failed. Please check the setup and try again."
    exit
}

# Copy all files from the toLocal folder to the local folder
Copy-Item -Path "$sourceDirectory\*" -Destination $localScriptPath -Recurse -Force

Write-Host "All necessary files copied to local storage for resilience against remote storage disconnection."

# Initialize user info
$userInfo = $config.UserInfo

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
    $response = Invoke-RestMethod -Uri "https://api.pushover.net/1/devices.json" -Method Post -Body @{
        token = "your_api_token_here"
        user = $userKey
    }

    if ($response.devices) {
        $userDevices = $response.devices | ForEach-Object { $_.name }
        Write-Host "Your devices: $($userDevices -join ', ')"

        # Prompt user to select devices for notifications or 'all' for all devices
        Write-Host "Enter the devices you want to receive notifications on (comma-separated), or type 'all' for all devices:"
        $selectedDevices = Read-Host

        if ($selectedDevices -eq 'all') {
            $selectedDevicesArray = @('all')
        } else {
            $selectedDevicesArray = $selectedDevices -split '\s*,\s*'
        }

        # Update user info in JSON
        $config.UserInfo = @{
            FirstName = $firstName
            LastName  = $lastName
            UserKey   = $userKey
            Devices   = $selectedDevicesArray
        }

        # Save updated config to file
        $config | ConvertTo-Json | Set-Content -Path $configPath
        Write-Host "User information saved."
    } else {
        Write-Host "Failed to retrieve devices. Please check your Pushover User Key."
        exit
    }
}

# Function to create a scheduled task
function Create-ScheduledTask {
    param (
        [string]$taskName,
        [string]$scriptPath,
        [string]$interval
    )

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval $interval -RepeatIndefinitely -Once -At (Get-Date).AddSeconds(30)
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Automated task for $taskName"
}

# Prompt user to enter intervals
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
