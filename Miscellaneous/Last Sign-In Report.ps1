<#
.SYNOPSIS
    Exports an Entra ID user snapshot to a CSV.

.DESCRIPTION
    Authenticates to Microsoft Graph, ensures required modules are present, and prompts for a destination CSV path (creating the folder if needed).
    Enumerates all users and records: UserPrincipalName, last interactive sign-in, last non-interactive sign-in, and whether the account is enabled;
    writes results to CSV with simple progress output. Optimized for PowerShell 7.

.NOTES
- Created 2024.09.26 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.27 at 1017 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Extract user account information from Entra and save it to a CSV file..."
Write-Host

# This script is optimized for PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Import the required modules if not already available
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.Accounts', 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users')
foreach ($module in $requiredModules) {
    if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to install module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Module '$module' is already installed." -ForegroundColor Green
    }

    try {
        Import-Module -Name $module -ErrorAction Stop
        Write-Host "Module '$module' imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to import module '$module'. Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Authenticate through Entra
Write-Host
Write-Host "Authenticating via Entra..." -ForegroundColor Cyan
try {
    Connect-MgGraph -ContextScope Process -NoWelcome -ErrorAction Stop
    Write-Host "Authentication successful." -ForegroundColor Green
} catch {
    Write-Host "Authentication failed. Error: $_" -ForegroundColor Red
    exit 1
}

# Define variables
Write-Host
Write-Host "Please enter the full path and filename of the CSV to save to: " -ForegroundColor Cyan -NoNewline
$csvFullPath = Read-Host

# Extract the directory path from the full path
$csvDirectory = Split-Path -Path $csvFullPath -Parent

# Check if the directory exists
if (-not (Test-Path -Path $csvDirectory)) {
    Write-Host "The directory '$csvDirectory' does not exist. Do you want to create it? (Y/N): " -ForegroundColor Cyan -NoNewline
    $createPath = Read-Host
    if ($createPath -eq 'Y' -or $createPath -eq 'y') {
        try {
            New-Item -ItemType Directory -Path $csvDirectory -Force -ErrorAction Stop
            Write-Host "Directory '$csvDirectory' created successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to create directory '$csvDirectory'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Directory creation aborted. Exiting script." -ForegroundColor Red
        exit 1
    }
}

# Initialize counters
$processedItemCount = 0
$totalItemCount = 0

# Retrieve user accounts with pagination
Write-Host
Write-Host "Retrieving user accounts from Entra..." -ForegroundColor Yellow
$userAccounts = @()
$users = Get-MgUser -All -Property 'UserPrincipalName,SignInActivity,AccountEnabled' -ErrorAction Stop
$totalItemCount = $users.Count

foreach ($user in $users) {
    $processedItemCount++
    $userAccount = [PSCustomObject]@{
        Username                = $user.UserPrincipalName
        LastInteractiveSignIn   = $user.SignInActivity.LastSignInDateTime
        LastNonInteractiveSignIn = $user.SignInActivity.LastNonInteractiveSignInDateTime
        AccountStatus           = if ($user.AccountEnabled) { "Enabled" } else { "Disabled" }
    }

    $userAccounts += $userAccount

    if ($processedItemCount % 125 -eq 0) {
        Write-Host "$processedItemCount items of $totalItemCount have been processed..." -ForegroundColor Yellow
    }
}

# Write to CSV
Write-Host
Write-Host "Writing user account information to CSV..." -ForegroundColor Yellow
try {
    $userAccounts | Export-Csv -Path $csvFullPath -NoTypeInformation -Force
    Write-Host "User account information successfully written to $csvFullPath" -ForegroundColor Green
} catch {
    Write-Host "Failed to write user account information to CSV. Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host
Write-Host "Script execution completed." -ForegroundColor Green