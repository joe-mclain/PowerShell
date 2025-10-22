<#
.SYNOPSIS
Deletes a selected Azure Key Vault after user confirmation.

.DESCRIPTION
- Retrieves the list of Azure Key Vaults.
- Prompts the user to select a Key Vault to delete.
- Confirms the deletion before proceeding.
- Deletes the selected Key Vault.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.20 at 1620 by Joe McLain (joe@bvu.edu)
#>

# Define the parameter that determines whether this script is being called by a control script
param (
    [switch]$isAuthenticated
)

Write-Host
Write-Host "Delete Azure Key Vault..." -ForegroundColor Blue
Write-Host

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Install and import required PowerShell modules
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.KeyVault', 'Az.Resources')
foreach ($module in $requiredModules) {
    # Check to see if the module is installed
    if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to install module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Module '$module' is already installed." -ForegroundColor Green
    }

    # Check to see if the module is already imported
    if (-not (Get-Module -ListAvailable -Name $module | Where-Object { $_.Name -eq $module })) {
        try {
            Import-Module -Name $module -ErrorAction Stop
            Write-Host "Module '$module' imported successfully." -ForegroundColor Green
        } catch {
            Write-Host "Failed to import module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Module '$module' is already imported." -ForegroundColor Green
    }
}

# If authentication hasn't been handled by a control script, authenticate
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    Connect-AzAccount -ErrorAction Stop
}

# Begin looping for vault deletion
do {
    # Retrieve all Key Vaults
    Write-Host
    Write-Host "Retrieving the list of Azure Key Vaults..." -ForegroundColor Cyan
    $keyVaults = Get-AzKeyVault
    if (-not $keyVaults) {
        Write-Host
        Write-Host "No Key Vaults found in the subscription." -ForegroundColor Red
        exit
    }

    # Display the list of Key Vaults in a numbered list
    for ($i = 0; $i -lt $keyVaults.Count; $i++) {
        Write-Host "$($i + 1). $($keyVaults[$i].VaultName) in $($keyVaults[$i].ResourceGroupName)"
    }

    # Prompt the user to select a Key Vault to delete
    $inputValid = $false
    do {
        Write-Host
        Write-Host "Enter the number of the Key Vault you want to delete: " -ForegroundColor Cyan -NoNewline
        $selectedIndex = (Read-Host).ToLower()

        if ($selectedIndex -eq '') {
            Write-Host
            Write-Host "Input cannot be empty. Please enter a valid number." -ForegroundColor Red
        }
        elseif ($selectedIndex -match '^\d+$' -and [int]$selectedIndex -gt 0 -and [int]$selectedIndex -le $keyVaults.Count) {
            $keyVaultName = $keyVaults[[int]$selectedIndex - 1].VaultName
            $inputValid = $true
        } else {
            Write-Host
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        }
    } while (-not $inputValid)

    # Confirm deletion
    $confirmDeletion = $false
    do {
        Write-Host
        Write-Host "Are you sure you want to delete the Key Vault '$keyVaultName'? (y/n): " -ForegroundColor DarkBlue -NoNewline
        $confirmInput = (Read-Host).ToLower()

        if ($confirmInput -eq 'y') {
            $confirmDeletion = $true
        } elseif ($confirmInput -eq 'n') {
            Write-Host "Deletion canceled." -ForegroundColor Yellow
            $confirmDeletion = $false
            break
        } else {
            Write-Host
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
        }
    } while (-not $confirmDeletion)

    # Proceed with deletion if confirmed
    if ($confirmDeletion) {
        try {
            Remove-AzKeyVault -VaultName $keyVaultName -Force
            Write-Host
            Write-Host "Key Vault '$keyVaultName' deleted successfully." -ForegroundColor Green
        } catch {
            Write-Host
            Write-Host "Failed to delete Key Vault '$keyVaultName'. Error: $_" -ForegroundColor Red
        }
    }

    # Ask if the user wants to delete another Key Vault
    do {
        Write-Host
        Write-Host "Would you like to delete another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $anotherDeletion = (Read-Host).ToLower()

        if ($anotherDeletion -eq '') {
            Write-Host "Input cannot be empty. Please enter 'y' or 'n'." -ForegroundColor Red
        }

    } while ($anotherDeletion -ne 'y' -and $anotherDeletion -ne 'n')

} while ($anotherDeletion -eq 'y')