# Load configuration from notifications JSON
$userConfigPath = "$env:OEPHYS_SCRIPT_PATH\configs\user_config.json"
# Load the user config from the JSON file
$userConfig = Get-Content -Path $userConfigPath | ConvertFrom-Json

# Ensure 'UserInfo' property exists
if (-not $userConfig.PSObject.Properties['UserInfo']) {
    Add-Member -InputObject $userConfig -MemberType NoteProperty -Name 'UserInfo' -Value @()
}
$userInfo = $userConfig.UserInfo

# Pushover API credentials from config
$apiToken = "agsvfrtdcnc7iqqwhps89nrgmcya5a"
$userKey = $userInfo.UserKey
$devices = $userInfo.Devices -join ','

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

function Validate-UserKey {
    param (
        [string]$userKey
    )

    $apiToken = "agsvfrtdcnc7iqqwhps89nrgmcya5a"  # Pushover API token

    # Make the POST request to validate the user key
    $response = Invoke-RestMethod -Uri "https://api.pushover.net/1/users/validate.json" -Method Post -Body @{
        user = $userKey
        token = $apiToken
    }

    # Debugging: Print full response content
    Write-Host "Debugging: Response Content:`n$response"

    # Check if the response status is 1 (valid user)
    if ($response.status -eq 1) {
        # Extract devices
        $devicesArray = $response.devices

        # Convert the devices array to a comma-separated string
        $devices = $devicesArray -join ', '

        Write-Host "User key is valid. Active devices: $devices"
        return $devices
    } else {
        Write-Host "Invalid user key or no active devices found."
        return @()  # Return an empty array if no devices or invalid user
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

# Function to add a property to a PSObject if it doesn't exist
function Ensure-PropertyExists {
    param (
        [psobject]$Object,
        [string]$PropertyName,
        [object]$DefaultValue
    )

    if (-not $Object.PSObject.Properties[$PropertyName]) {
        $Object | Add-Member -MemberType NoteProperty -Name $PropertyName -Value $DefaultValue
    }
}