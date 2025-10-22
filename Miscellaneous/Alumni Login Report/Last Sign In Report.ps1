### The purpose of this script is to identify how long after graduation our alumni need their accounts.
### This script will take a CSV in the format UPN,Date and look up all sign-in dates for each user.
###  It will find the most recent sign-in date for each user and calculate various metrics to help 
###  determine how long accounts should be retained post-graduation.
###  Individual information collected for each user will be saved in a file named GradList_Metrics.txt.
#
### NOTE: The CSV file needs to be named GradList.csv, be saved in the same folder as this script,
###  and have column headings in row 1 such as "UPN,GraduationDate". The script will check and add
###  the headers if they are missing.
#
### This script was written 2024.08.13 by Joe McLain (joe@bvu.edu).
### This script was last updated 2024.08.13 at 1342 by Joe McLain (joe@bvu.edu).


# Clear the screen to make it easy to see the output of each run
Clear-Host

# This script is optimized for PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Define variables
$tenantId = "d22ee457-c206-4c03-a345-b80fd05f20e8"

# Function to check and install/update specific PowerShell modules
function Ensure-Module {
    param (
        [string]$moduleName
    )

    # Check if the module is loaded
    if (Get-Module -Name $moduleName) {
        Write-Host "Module '$moduleName' is already loaded. Attempting to remove it before re-importing..." -ForegroundColor Yellow
        Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    }

    # Check if the module is installed
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Write-Host "Module '$moduleName' is not installed. Installing now..." -ForegroundColor Cyan
        Install-Module -Name $moduleName -AllowClobber -Force -Scope CurrentUser
    } else {
        Write-Host "Module '$moduleName' is already installed." -ForegroundColor Cyan
    }

    # Import the module
    Write-Host "Importing module '$moduleName'..." -ForegroundColor Cyan
    try {
        Import-Module $moduleName -ErrorAction Stop
    } catch {
        Write-Host "Failed to import module '$moduleName'. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
}

# Ensure required modules from Microsoft.Graph are installed and loaded
Write-Host "Ensuring that the required PowerShell modules are installed and updated" -ForegroundColor Cyan
Ensure-Module -moduleName "Microsoft.Graph.Authentication"
Ensure-Module -moduleName "Microsoft.Graph.Users"

# Authenticate with Microsoft Graph
Write-Host "Authenticating with Microsoft Graph..." -ForegroundColor Cyan
try {
    Connect-MgGraph -TenantId $tenantId -Scopes "User.Read.All" -NoWelcome -ErrorAction Stop > $null
} catch {
    Write-Host "Failed to authenticate with Microsoft Graph. Error: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Define the list of users and their graduation dates
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$csvPath = Join-Path -Path $scriptDir -ChildPath "GradList.csv"

# Check if the CSV file exists
if (-Not (Test-Path $csvPath)) {
    Write-Host "CSV file not found: $csvPath" -ForegroundColor Red
    exit
}

# Read the first line of the CSV file to check for the header
$firstLine = Get-Content -Path $csvPath -TotalCount 1

if ($firstLine -ne "UPN,GraduationDate") {
    Write-Host "Headers missing from CSV file. Adding headers now..." -ForegroundColor Yellow
    $csvContent = Get-Content -Path $csvPath
    Set-Content -Path $csvPath -Value "UPN,GraduationDate"
    Add-Content -Path $csvPath -Value $csvContent
}

Write-Host "Loading user data from CSV file..." -ForegroundColor Cyan
$users = Import-Csv $csvPath

# Function to get last successful sign-in activity data using Microsoft Graph module
function Get-LastSuccessfulSignInActivity {
    param (
        [string]$userPrincipalName
    )

    try {
        # Fetch the user information with SignInActivity property using Get-MgUser
        $user = Get-MgUser -Filter "userPrincipalName eq '$userPrincipalName'" -Property 'SignInActivity'
        if ($user.SignInActivity.LastSignInDateTime) {
            return [datetime]::Parse($user.SignInActivity.LastSignInDateTime)
        } else {
            return $null
        }
    } catch {
        Write-Host "Error retrieving sign-in activity data for $($userPrincipalName): $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Calculate days beyond graduation
Write-Host "Calculating days beyond graduation for each user..." -ForegroundColor Cyan
$results = [System.Collections.Generic.List[pscustomobject]]::new() 
$counter = 0
foreach ($user in $users) {
    if (-not [string]::IsNullOrEmpty($user.GraduationDate)) {
        try {
            $graduationDate = [datetime]::ParseExact($user.GraduationDate, "MM/dd/yyyy", $null)
        } catch {
            Write-Host "Invalid graduation date for $($user.UPN): $($user.GraduationDate)" -ForegroundColor Red
            continue
        }

        $lastSignInDate = Get-LastSuccessfulSignInActivity -userPrincipalName $user.UPN

        if ($lastSignInDate) {
            $daysBeyondGraduation = ($lastSignInDate - $graduationDate).Days
            $results.Add([pscustomobject]@{
                UPN = $user.UPN
                GraduationDate = $graduationDate
                LastSignInDate = $lastSignInDate
                DaysBeyondGraduation = $daysBeyondGraduation
            })
        }
    } else {
        Write-Host "Missing graduation date for $($user.UPN)" -ForegroundColor Yellow
    }

    # Increment counter and provide progress update every 100 items
    $counter++
    if ($counter % 100 -eq 0) {
        $time = Get-Date -Format "HH:mm"
        Write-Host "It's $time and I'm still working. Please be patient"
    }
}

# Output the results to a file
$results | Format-Table -AutoSize | Out-File -FilePath "$scriptDir\GradList_Metrics.txt" -Force

# Calculate and display statistics
if ($results.Count -gt 0) {
    $averageDays = [math]::Round(($results | Measure-Object -Property DaysBeyondGraduation -Average).Average)
    $averageMonths = [math]::Round($averageDays / 30)

    $sortedResults = $results | Sort-Object -Property DaysBeyondGraduation
    $medianDays = [math]::Round($sortedResults[$sortedResults.Count / 2].DaysBeyondGraduation)
    $medianMonths = [math]::Round($medianDays / 30)

    $maxDays = [math]::Round(($results | Measure-Object -Property DaysBeyondGraduation -Maximum).Maximum)
    $maxMonths = [math]::Round($maxDays / 30)

    $minDays = [math]::Round(($results | Measure-Object -Property DaysBeyondGraduation -Minimum).Minimum)
    $stdDevDays = [math]::Round(($results | Measure-Object -Property DaysBeyondGraduation -StandardDeviation).StandardDeviation)

    Write-Host "Average months beyond departure: $averageMonths" -ForegroundColor Green
    Write-Host "Median months beyond departure: $medianMonths" -ForegroundColor Green
    Write-Host "Minimum days beyond departure: $minDays" -ForegroundColor Green
    Write-Host "Maximum months beyond departure: $maxMonths" -ForegroundColor Green
    Write-Host "Standard deviation of days beyond departure: $stdDevDays" -ForegroundColor Green
}

# Example of percentage of accounts going inactive within specific intervals
$intervals = @(
    @{ Label = "within 6 months of departure"; MaxDays = 180 },
    @{ Label = "within 1 year of departure"; MaxDays = 365 },
    @{ Label = "within 18 months of departure"; MaxDays = 548 },
    @{ Label = "within 2 years of departure"; MaxDays = 730 }
)
Write-Host
foreach ($interval in $intervals) {
    $activeCount = ($results | Where-Object { $_.DaysBeyondGraduation -le $interval.MaxDays }).Count
    $percentageActive = [math]::Round(($activeCount / $results.Count) * 100)
    Write-Host "Percentage of accounts going inactive $($interval.Label): $percentageActive%" -ForegroundColor Green
}
Write-Host

Write-Host "Script execution completed." -ForegroundColor Cyan