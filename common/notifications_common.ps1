# Load configuration from notifications JSON
$notificationsConfigPath = "$PSScriptRoot\..\notifications_config.json"
$notificationsConfig = Get-Content -Path $notificationsConfigPath | ConvertFrom-Json

# Pushover API credentials from config
$apiToken = "agsvfrtdcnc7iqqwhps89nrgmcya5a"
$userKey = $notificationsConfig.UserInfo.UserKey
$devices = $notificationsConfig.UserInfo.Devices -join ','

# Function to send a Pushover notification
function Send-Notification {
    param (
        [string]$message,
        [string]$title = "Open Ephys Notification",
        [string]$priority = "0",  # Normal priority
        [string]$sound = "pushover"
    )

    # Send a Pushover notification
    Invoke-RestMethod -Uri "https://api.pushover.net/1/messages.json" -Method Post -Body @{
        token = $apiToken
        user = $userKey
        device = $devices
        message = $message
        title = $title
        priority = $priority
        sound = $sound
    }
}

# Function to retrieve user's devices from Pushover API
function Get-UserDevices {
    try {
        $response = Invoke-RestMethod -Uri "https://api.pushover.net/1/devices.json" -Method Post -Body @{
            token = $apiToken
            user = $userKey
        }

        if ($response.devices) {
            $userDevices = $response.devices | ForEach-Object { $_.name }
            return $userDevices
        } else {
            Write-Host "No devices found for the user in Pushover."
            return @()
        }
    } catch {
        Write-Host "Error retrieving devices from Pushover: $_"
        return @()
    }
}

# Function to validate if user has selected valid devices
function Validate-SelectedDevices {
    param (
        [array]$selectedDevices
    )

    $availableDevices = Get-UserDevices

    foreach ($device in $selectedDevices) {
        if ($device -ne 'all' -and -not ($availableDevices -contains $device)) {
            Write-Host "Invalid device: $device. Available devices are: $($availableDevices -join ', ')"
            return $false
        }
    }

    return $true
}
