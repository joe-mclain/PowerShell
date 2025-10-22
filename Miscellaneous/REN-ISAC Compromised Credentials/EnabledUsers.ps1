# This script will take a list of usernames and check to see if any of the accounts are still enabled.
# The intended purpose was to take a list of users provided by REN-ISAC whose credentials were involved
# in a breach and determine who needs to be notified so they can do password resets anywhere and everywhere.

# NOTE: The user file needs to be named UserList.txt, be saved in the same folder as this script,
#  and each UPN should be on its own line.

# This script was written by Joe McLain (joe@bvu.edu)
# This script was last updated 2024.09.16 at 1625 by Joe McLain (joe@bvu.edu)

# Clear the screen to make it easy to see the output of each run
Clear-Host

# This script is optimized for PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Install the required PowerShell modules if not already available
$requiredModules = @("Microsoft.Graph.Users")

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing required module: $module" -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Force -Scope CurrentUser -AllowClobber
        } catch {
            Write-Host "Failed to install $module. Exiting..." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Module $module is already installed." -ForegroundColor Green
    }
    
    # Import the module if it's not already imported
    if (-not (Get-Module -Name $module)) {
        Write-Host "Importing module: $module" -ForegroundColor Yellow
        try {
            Import-Module -Name $module
        } catch {
            Write-Host "Failed to import $module. Exiting..." -ForegroundColor Red
            exit 1
        }
    }
}

# Connect to the Microsoft.Graph module
Write-Host
Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -Scopes "User.Read.All", "Group.ReadWrite.All" -NoWelcome
} catch {
    Write-Host "Failed to connect to Microsoft.Graph. Exiting..." -ForegroundColor Red
    exit 1
}

# Ensure any existing EnabledUserList.txt is deleted to start fresh
$enabledUserFilePath = Join-Path -Path "." -ChildPath "EnabledUserList.txt"
try {
    if (Test-Path $enabledUserFilePath) {
        Remove-Item $enabledUserFilePath
    }
} catch {
    Write-Host "Failed to delete existing EnabledUserList.txt. Exiting..." -ForegroundColor Red
    exit 1
}

# Initialize a flag to track if any enabled users are found
$anyEnabledUsers = $false

# Check the user list for active users
Write-Host
Write-Host "Checking the status of each user..." -ForegroundColor Cyan
try {
    $users = Get-Content -Path ".\UserList.txt"
} catch {
    Write-Host "Failed to read UserList.txt. Exiting..." -ForegroundColor Red
    exit 1
}

foreach ($user in $users) {
    try {
        $graphUser = Get-MgUser -UserId $user -Property AccountEnabled -ErrorAction Stop
        
        if ($graphUser.AccountEnabled) {
            Write-Host "$user is enabled." -ForegroundColor Green
            # Append enabled user to the file
            $user | Add-Content -Path $enabledUserFilePath
            $anyEnabledUsers = $true
        } else {
            Write-Host "$user is disabled." -ForegroundColor Yellow
        }
    } catch {
        # Instead of writing an error, indicate the user was not found
        Write-Host "$user was not found in Entra." -ForegroundColor Blue
    }
}

# Display the appropriate message based on whether any enabled users were found
Write-Host
if ($anyEnabledUsers) {
    Write-Host "All users with enabled accounts can be found in $enabledUserFilePath" -ForegroundColor Cyan
} else {
    Write-Host "All user accounts were disabled" -ForegroundColor Cyan
}