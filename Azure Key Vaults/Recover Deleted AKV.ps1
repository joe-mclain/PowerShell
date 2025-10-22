<#
.SYNOPSIS
Recovers a deleted Azure Key Vault using Azure CLI, with guided selection and validation.

.DESCRIPTION
- Prompts the user to select a deleted Key Vault to recover.
- Uses Azure CLI to perform the recovery operation.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.14 at 1501 by Joe McLain (joe@bvu.edu)
#>

# Revised Recover Deleted Azure Key Vault Script

param (
    [switch]$isAuthenticated
)

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor DarkCyan
    do {
        Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $continue = (Read-Host).ToLower()
    } while ($continue -notmatch '^(y|n)$')
    if ($continue -eq 'y') { & $MyInvocation.MyCommand.Path }
    exit
}

Write-Host
Write-Host "Recover Deleted Azure Key Vault..." -ForegroundColor Blue
Write-Host

# Ensure requisite PowerShell modules are installed and imported.
Write-Host "Checking for the required PowerShell modules..." -ForegroundColor DarkCyan
$requiredModules = @('Az.KeyVault')
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
        do {
            Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
            $continue = (Read-Host).ToLower()
        } while ($continue -notmatch '^(y|n)$')
        if ($continue -eq 'y') { & $MyInvocation.MyCommand.Path }
        exit
    }
}

# Authenticate to Azure if not already authenticated (Azure PowerShell)
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure with Azure PowerShell..." -ForegroundColor DarkCyan
    try {
        Connect-AzAccount -ErrorAction Stop
        Write-Host "Authentication successful." -ForegroundColor Green
    } catch {
        Write-Host "Authentication failed. Error: $_" -ForegroundColor Red
        do {
            Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
            $continue = (Read-Host).ToLower()
        } while ($continue -notmatch '^(y|n)$')
        if ($continue -eq 'y') { & $MyInvocation.MyCommand.Path }
        exit
    }
}

# Look up and set the Azure subscription before authentication
Write-Host
Write-Host "Looking up Azure subscriptions..." -ForegroundColor DarkCyan
try {
    # Retrieve available subscriptions
    $subscriptions = az account list --output json | ConvertFrom-Json

    if ($subscriptions.Count -eq 0) {
        throw "No Azure subscriptions found. Please ensure your account has access to at least one subscription."
    }

    # Select default or prompt the user for subscription choice if multiple exist
    $defaultSubscription = $subscriptions | Where-Object { $_.isDefault -eq $true }
    if ($defaultSubscription -eq $null) {
        # No default subscription; prompt user
        Write-Host "No default subscription found. Please select a subscription from the list below:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $subscriptions.Count; $i++) {
            Write-Host "$($i + 1). $($subscriptions[$i].name) (ID: $($subscriptions[$i].id))"
        }
        $selection = $null
        while (-not $selection) {
            Write-Host "Enter the number of the subscription to use: " -ForegroundColor Cyan -NoNewline
            $input = Read-Host
            if ($input -match '^\d+$' -and [int]$input -gt 0 -and [int]$input -le $subscriptions.Count) {
                $selection = $subscriptions[[int]$input - 1]
            } else {
                Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
            }
        }
        $subscriptionId = $selection.id
    } else {
        # Use the default subscription
        $subscriptionId = $defaultSubscription.id
        Write-Host "Default subscription detected: $($defaultSubscription.name) (ID: $subscriptionId)" -ForegroundColor Green
    }

    # Set the selected subscription for Azure CLI
    az account set --subscription $subscriptionId
    Write-Host "Subscription set to: $subscriptionId" -ForegroundColor Green

} catch {
    Write-Host "Failed to look up or set the Azure subscription. Error: $_" -ForegroundColor Red
    exit
}

# Authenticate to Azure CLI with the selected subscription
Write-Host
Write-Host "Authenticating to Azure CLI..." -ForegroundColor DarkCyan
try {
    Write-Host "Logging into Azure CLI for subscription $subscriptionId..." -ForegroundColor Cyan
    az login --output none
    Write-Host "Azure CLI authentication successful with subscription: $subscriptionId" -ForegroundColor Green
} catch {
    Write-Host "Azure CLI authentication failed. Error: $_" -ForegroundColor Red
    exit
}

# Function to list and select a deleted Key Vault
function Select-DeletedKeyVault {
    try {
        $deletedVaults = Get-AzKeyVault -InRemovedState -ErrorAction Stop
    } catch {
        Write-Host "Failed to retrieve deleted Key Vaults. Error: $_" -ForegroundColor Red
        do {
            Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
            $continue = (Read-Host).ToLower()
        } while ($continue -notmatch '^(y|n)$')
        if ($continue -eq 'y') { & $MyInvocation.MyCommand.Path }
        exit
    }

    if (-not $deletedVaults) {
        Write-Host "No deleted Azure Key Vaults found in the subscription." -ForegroundColor Red
        do {
            Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
            $continue = (Read-Host).ToLower()
        } while ($continue -notmatch '^(y|n)$')
        if ($continue -eq 'y') { & $MyInvocation.MyCommand.Path }
        exit
    }

    Write-Host
    Write-Host "Available Deleted Key Vaults:" -ForegroundColor DarkCyan
    for ($i = 0; $i -lt $deletedVaults.Count; $i++) {
        Write-Host "$($i + 1). $($deletedVaults[$i].VaultName) in Resource Group: $($deletedVaults[$i].ResourceGroupName) (Location: $($deletedVaults[$i].Location))"
    }

    $selection = $null
    while (-not $selection) {
        Write-Host "Enter the number of the Key Vault to recover: " -ForegroundColor Cyan -NoNewline
        $input = Read-Host
        if ($input -match '^\d+$' -and [int]$input -gt 0 -and [int]$input -le $deletedVaults.Count) {
            $selection = $deletedVaults[[int]$input - 1]
        } else {
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        }
    }

    return $selection
}

# Function to recover a deleted Key Vault
function Recover-KeyVault {
    param (
        [string]$keyVaultName
    )

    try {
        Write-Host
        Write-Host "Recovering deleted Key Vault '$keyVaultName' using Azure CLI..." -ForegroundColor Blue
        $recoveryCommand = "az keyvault recover --name $keyVaultName"
        $recoveryOutput = Invoke-Expression $recoveryCommand 2>&1

        if ($recoveryOutput -match "Status: Response_Status.Status_InteractionRequired") {
            Write-Host "Azure CLI requires additional interactive authentication." -ForegroundColor Yellow
            az login --output none
            # Attempt recovery again after re-authentication
            $recoveryOutput = Invoke-Expression $recoveryCommand 2>&1
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Key Vault '$keyVaultName' recovered successfully." -ForegroundColor Green
        } else {
            throw "Failed to recover Key Vault. Output: $recoveryOutput"
        }
    } catch {
        Write-Host "Error during recovery: $_" -ForegroundColor Red
        do {
            Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
            $continue = (Read-Host).ToLower()
        } while ($continue -notmatch '^(y|n)$')
        if ($continue -eq 'y') { & $MyInvocation.MyCommand.Path }
        exit
    }
}

# Main script loop
do {
    # Prompt for Key Vault selection
    $selectedKeyVault = Select-DeletedKeyVault
    $keyVaultName = $selectedKeyVault.VaultName

    # Call the recovery function
    Recover-KeyVault -keyVaultName $keyVaultName

    # Ask if the user wants to recover another Key Vault with input validation
    do {
        Write-Host
        Write-Host "Would you like to recover another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $continue = (Read-Host).ToLower()
    } while ($continue -notmatch '^(y|n)$')

} while ($continue -eq 'y')
