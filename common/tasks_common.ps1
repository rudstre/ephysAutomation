# Import necessary modules for task scheduling
try {
    Import-Module ScheduledTasks -ErrorAction Stop
} catch {
    Write-Host "Error importing ScheduledTasks module: $_"
    exit 1
}

# Function to get the interval input from the user and convert it to a TimeSpan
function Get-IntervalInput {
    param (
        [string]$taskDescription
    )
    
    do {
        Write-Host "Enter the interval for $taskDescription (e.g., '60s' for 60 seconds, '2m' for 2 minutes):"
        $input = Read-Host
        
        if ($input -match '^\d+[sm]$') {
            if ($input -like '*s') {
                return New-TimeSpan -Seconds ([int]($input -replace 's',''))
            } elseif ($input -like '*m') {
                return New-TimeSpan -Minutes ([int]($input -replace 'm',''))
            }
        } else {
            Write-Host "Invalid input. Please enter a valid interval (e.g., '60s' or '2m')."
        }
    } while ($true)
}

# Function to create a scheduled task
function Create-ScheduledTask {
    param (
        [string]$taskName,
        [string]$scriptPath,
        [TimeSpan]$intervalSpan  # Interval as a TimeSpan object
    )

    Write-Host "Creating task with interval: $($intervalSpan.TotalSeconds) seconds"  # Debugging output

    # Check if the task already exists
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Write-Host "A scheduled task with the name '$taskName' already exists. Removing the existing task."
        Remove-ScheduledTask -taskName $taskName
    }

    # Ensure that the repetition interval is at least 1 minute
    if ($intervalSpan -lt [TimeSpan]::FromMinutes(1)) {
        $intervalSpan = [TimeSpan]::FromMinutes(1)
        Write-Host "Repetition interval is too short; adjusted to 1 minute minimum."
    }

    # Create an action to run the script
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$scriptPath`""
    
    # Create a trigger based on the provided interval
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(30) `
        -RepetitionInterval $intervalSpan `
        -RepetitionDuration (New-TimeSpan -Days 1)  # Sets to 1-day duration
    
    # Register the scheduled task with the specified name, action, and trigger
    try {
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "Automated task for $taskName"
        Write-Host "Scheduled task '$taskName' created successfully."
    } catch {
        Write-Host "Error creating scheduled task '$taskName': $_"
    }
}

# Function to remove a scheduled task
function Remove-ScheduledTask {
    param (
        [string]$taskName
    )

    Write-Host "Removing scheduled task: $taskName"

    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Scheduled task '$taskName' removed successfully."
    } catch {
        Write-Host "Error removing scheduled task '$taskName': $_"
    }
}

function Check-ScheduledTask {
    param (
        [string]$taskName
    )

    # Check if the scheduled task exists and is enabled
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Ready') {
        return $true
    } else {
        return $false
    }
}
