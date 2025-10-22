<#
.SYNOPSIS
Lists all Azure Key Vaults in the current subscription.

.DESCRIPTION
- Retrieves all Key Vaults in the subscription.
- Displays each Key Vault's name and its resource group.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.13 at 1124 by Joe McLain (joe@bvu.edu)
#>

param (
    [switch]$isAuthenticated
)

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor DarkCyan
    exit
}

Write-Host
Write-Host "List Azure Key Vaults..." -ForegroundColor DarkCyan
Write-Host

# Define required modules
$requiredModules = @('Az.KeyVault')

# Make sure the requisite PowerShell modules are installed and imported.
Write-Host "Checking for the required PowerShell modules..." -ForegroundColor Blue
foreach ($module in $requiredModules) {
    try {
        if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
            Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        } else {
            Write-Host "Module '$module' is already installed." -ForegroundColor Green
        }

        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Importing module '$module'..." -ForegroundColor Yellow
            Import-Module -Name $module -ErrorAction Stop
            Write-Host "Module '$module' imported successfully." -ForegroundColor Green
        } else {
            Write-Host "Module '$module' is already imported." -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to install or import module '$module'. Error: $_" -ForegroundColor Red
        exit 1
    }
}

# If authentication hasn't been handled by the control script, authenticate
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure..." -ForegroundColor DarkCyan
    try {
        Connect-AzAccount -ErrorAction Stop
        Write-Host "Authenticated to Azure successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to authenticate to Azure. Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Retrieve and display Key Vaults
Write-Host "Retrieving the list of Azure Key Vaults..." -ForegroundColor DarkCyan
try {
    $keyVaults = Get-AzKeyVault -ErrorAction Stop
    if (-not $keyVaults) {
        Write-Host "No Key Vaults found in the subscription." -ForegroundColor Red
        exit
    }

    foreach ($kv in $keyVaults) {
        Write-Host "Key Vault $($kv.VaultName) in located in the $($kv.ResourceGroupName) Resource Group"
    }
} catch {
    Write-Host "Failed to retrieve the list of Key Vaults. Error: $_" -ForegroundColor Red
    exit 1
}

# Loop for user input validation
do {
    Write-Host
    Write-Host "Would you like to list Key Vaults again? (y/n): " -ForegroundColor DarkCyan -NoNewline
    $continue = (Read-Host).Trim().ToLower()

    if ($continue -notmatch '^(y|n)$') {
        Write-Host "Invalid input. Please enter 'y' for Yes or 'n' for No." -ForegroundColor Red
    }
} while ($continue -notmatch '^(y|n)$')

if ($continue -eq 'y') {
    Write-Host "Restarting the Key Vault listing..." -ForegroundColor DarkCyan
    # Optional: Implement logic to restart the process
} else {
    Write-Host "Exiting the script." -ForegroundColor DarkCyan
}