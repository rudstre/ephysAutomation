# Import necessary module
Import-Module ScheduledTasks

# Function to create a scheduled task
function Create-ScheduledTask {
    param (
        [string]$taskName,
        [string]$scriptPath,
        [string]$interval  # Interval in seconds (e.g., "60s" or "2m")
    )

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Seconds ([TimeSpan]::Parse($interval).TotalSeconds)) -RepeatIndefinitely -Once -At (Get-Date).AddSeconds(30)
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Automated task for $taskName"
    Write-Host "Scheduled task '$taskName' created successfully."
}

# Function to remove a scheduled task
function Remove-ScheduledTask {
    param (
        [string]$taskName
    )

    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Scheduled task '$taskName' removed successfully."
    } else {
        Write-Host "Scheduled task '$taskName' not found."
    }
}

# Function to check if a scheduled task exists
function Check-ScheduledTask {
    param (
        [string]$taskName
    )

    $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($taskExists) {
        Write-Host "Scheduled task '$taskName' is running."
        return $true
    } else {
        Write-Host "Scheduled task '$taskName' is not running."
        return $false
    }
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
