<#
.SYNOPSIS
Provides a menu-driven launcher for Azure Key Vault management tasks.

.DESCRIPTION
- Displays a menu of Key Vault actions for the user to choose from.
- Invokes the appropriate script based on the selected action.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.14 at 1539 by Joe McLain (joe@bvu.edu)
#>

# Clear screen for readability
Clear-Host

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Blue
    exit
}

Write-Host
Write-Host "Manage Azure Key Vaults..." -ForegroundColor DarkBlue
Write-Host

# Install and import required PowerShell modules
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Blue
$requiredModules = @('Az.Accounts', 'Az.KeyVault')
foreach ($module in $requiredModules) {
    try {
        # Check to see if the module is installed
        if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
            Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        } else {
            Write-Host "Module '$module' is already installed." -ForegroundColor Green
        }

        # Check to see if the module is imported
        if (-not (Get-Module -ListAvailable -Name $module | Where-Object { $_.Name -eq $module })) {
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

# Authenticate to Azure
Write-Host
Write-Host "Authenticating to Azure..." -ForegroundColor Blue
try {
    Connect-AzAccount -ErrorAction Stop
    Write-Host "Authentication successful." -ForegroundColor Green
} catch {
    Write-Host "Authentication failed. Error: $_" -ForegroundColor Red
    exit 1
}

# Main menu to select actions
$isAuthenticated = $true
do {
    Write-Host
    Write-Host "Azure Key Vault Management Menu" -ForegroundColor Blue
    Write-Host "1. List Azure Key Vaults"
    Write-Host "2. Inventory Key Vaults"
    Write-Host "3. Create a Key Vault"
    Write-Host "4. Delete a Key Vault"
    Write-Host "5. Change Ownership of Key Vault"
    Write-Host "6. Backup a Key Vault"
    Write-Host "7. Restore a Key Vault from Backup"
    Write-Host "8. Configure Analytics Reporting for Key Vault"
    Write-Host "9. Recover Deleted Key Vault"
    Write-Host "10. Manage Firewall Controls for Key Vault"
    Write-Host "11. Audit Key Vault Access" -ForegroundColor Yellow
    Write-Host "12. Exit"
    Write-Host
    Write-Host "Enter your choice (1-12): " -ForegroundColor Blue -NoNewline
    $choice = Read-Host

    # Validate user input
    while (-not ($choice -match '^\d+$') -or [int]$choice -lt 1 -or [int]$choice -gt 12) {
        Write-Host "Invalid selection. Please enter a number between 1 and 12." -ForegroundColor Red
        Write-Host "Enter your choice (1-12): " -ForegroundColor Blue -NoNewline
        $choice = Read-Host
    }

    Clear-Host

    # Switch statement for user choice
    switch ([int]$choice) {
        1 { & ".\List AKVs.ps1" -isAuthenticated $isAuthenticated }
        2 { & ".\Inventory AKVs.ps1" -isAuthenticated $isAuthenticated }
        3 { & ".\Create AKV.ps1" -isAuthenticated $isAuthenticated }
        4 { & ".\Delete AKV.ps1" -isAuthenticated $isAuthenticated }
        5 { & ".\Change Ownership of AKV.ps1" -isAuthenticated $isAuthenticated }
        6 { & ".\Backup AKV.ps1" -isAuthenticated $isAuthenticated }
        7 { & ".\Restore AKV.ps1" -isAuthenticated $isAuthenticated }
        8 { & ".\Configure Analytics Reporting for AKV.ps1" -isAuthenticated $isAuthenticated }
        9 { & ".\Recover Deleted AKV.ps1" -isAuthenticated $isAuthenticated }
        10 { & ".\AKV Firewall Controls.ps1" -isAuthenticated $isAuthenticated }
        11 { & ".\Audit AKV Access.ps1" -isAuthenticated $isAuthenticated }
        12 { exit }
        default { Write-Host "Invalid selection. Please choose a valid option." -ForegroundColor Red } # Should not reach here due to validation
    }

    Write-Host
    Write-Host "Would you like to perform another Azure Key Vault action? (y/n): " -ForegroundColor Blue -NoNewline
    $continue = Read-Host

    # Validate user input for continuation
    while (-not $continue -match '^(y|n)$') {
        Write-Host "Invalid input. Please enter 'y' to continue or 'n' to exit." -ForegroundColor Red
        Write-Host "Would you like to perform another Azure Key Vault action? (y/n): " -ForegroundColor Blue -NoNewline
        $continue = Read-Host
    }

} while ($continue -eq 'y')