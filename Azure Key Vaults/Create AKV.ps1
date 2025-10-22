<#
.SYNOPSIS
Creates an Azure Key Vault with user-specified settings and optional owner assignment.

.DESCRIPTION
- Prompts for required details (name, location, retention, purge protection, resource group).
- Creates the Key Vault.
- Optionally assigns additional AKV owners by invoking a companion script.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.20 at 1725 by Joe McLain (joe@bvu.edu)
#>

# Define the parameter that determines whether this script is being called by a control script
param (
    [switch]$isAuthenticated
)

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

Write-Host
Write-Host "Create Azure Key Vault..." -ForegroundColor Blue
Write-Host

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

# If authentication hasn't been handled by the control script, authenticate
if (-not $isAuthenticated) {
    Write-Host
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    Connect-AzAccount -ErrorAction Stop
}

# Function to validate Key Vault name
function Validate-KeyVaultName {
    param(
        [string]$kvName
    )
    if ($kvName.Length -lt 3 -or $kvName.Length -gt 24) {
        return "Key Vault name must be between 3 and 24 characters."
    }
    if ($kvName -match '[^a-zA-Z0-9-]') {
        return "Key Vault name can only contain alphanumeric characters (A-Z, 0-9) and hyphens (-)."
    }
    if ($kvName -match '--') {
        return "Key Vault name cannot contain consecutive hyphens."
    }
    if ($kvName -notmatch '^[a-zA-Z]') {
        return "Key Vault name must start with a letter."
    }
    if ($kvName -notmatch '[a-zA-Z0-9]$') {
        return "Key Vault name must end with a letter or digit."
    }
    return $null
}

# Function to create Key Vault
function CreateKeyVault {
    param(
        [string]$keyVaultName,
        [string]$resourceGroupName,
        [int]$softDeleteRetentionPeriod,
        [bool]$enablePurgeProtection
    )

    $retry = $true
    while ($retry) {
        try {
            # Confirmation before creation
Write-Host
Write-Host "You are about to create a Key Vault with the following details:" -ForegroundColor Blue
Write-Host "  Key Vault Name: $keyVaultName" -ForegroundColor Blue
Write-Host "  Resource Group: $resourceGroupName" -ForegroundColor Blue
Write-Host "  Soft Delete Retention Period: $softDeleteRetentionPeriod days" -ForegroundColor Blue
Write-Host "  Purge Protection: $enablePurgeProtection" -ForegroundColor Blue
Write-Host

$validInput = $false
while (-not $validInput) {
    Write-Host "Do you want to proceed? (y/n): " -ForegroundColor Cyan -NoNewline
    $confirmation = (Read-Host).ToLower()

    if ($confirmation -eq 'y') {
        $validInput = $true
    } elseif ($confirmation -eq 'n') {
        Write-Host
        Write-Host "Action canceled." -ForegroundColor Yellow
        return $false
    } else {
        Write-Host
        Write-Host "Invalid input. Please enter 'y' to proceed or 'n' to cancel." -ForegroundColor Red
    }
}

            # Prepare the key vault creation command
            $keyVaultCommand = @"
                New-AzKeyVault -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -Location centralus -SoftDeleteRetentionInDays $softDeleteRetentionPeriod
"@ 

            # If purge protection is enabled, add the -EnablePurgeProtection switch (no value)
            if ($enablePurgeProtection) {
                $keyVaultCommand += " -EnablePurgeProtection"
            }

            # Execute the key vault creation command
            Invoke-Expression $keyVaultCommand

            # Check to see if the vault was created successfully
            $createdVault = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName
            if ($createdVault) {
                Write-Host
                Write-Host "Azure Key Vault '$keyVaultName' has been created successfully in Resource Group '$resourceGroupName'." -ForegroundColor Green
                $retry = $false  # Exit loop on success
                return $true
            } else {
                throw "Key Vault creation failed."
            }
        } catch {
            Write-Host
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host
            Write-Host "Key Vault creation failed. The name '$keyVaultName' might already be in use or another error occurred." -ForegroundColor Red
            
            # Ask for retry or exit
            Write-Host
            Write-Host "Would you like to retry with a new Key Vault name? (y/n): " -ForegroundColor Cyan -NoNewline
            $response = (Read-Host).ToLower()
            if ($response -eq 'n') {
                $retry = $false  # Exit loop
                Write-Host "Exiting the Key Vault creation process." -ForegroundColor Yellow
                return $false
            } else {
                Write-Host "Enter a new Key Vault name: " -ForegroundColor Cyan -NoNewLine
                $keyVaultName = Read-Host
            }
        }
    }
}

# Function to prompt the user and assign the AKV Owner role
function Assign-AKVOwnerRole {
    $assignOwnerValid = $false
    do {
        Write-Host
        Write-Host "Would you like to assign the AKV Owner role to this Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $assignOwner = Read-Host
        $assignOwner = $assignOwner.ToLower()

        if ($assignOwner -eq 'y') {
            Write-Host
            Write-Host "Assigning AKV Owner role..." -ForegroundColor Yellow
            try {
                & ".\Change Ownership of AKV.ps1" -isAuthenticated $isAuthenticated
                $assignOwnerValid = $true
            }
            catch {
                Write-Host
                Write-Host "Failed to assign AKV Owner role. Error: $_" -ForegroundColor Red
                $assignOwnerValid = $false
            }
        }
        elseif ($assignOwner -eq 'n') {
            Write-Host
            Write-Host "No owner assignment performed." -ForegroundColor Yellow
            $assignOwnerValid = $true
        }
        else {
            Write-Host
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
            $assignOwnerValid = $false
        }
    } while (-not $assignOwnerValid)
}

# Main loop
do {
    # List all existing resource groups
    Write-Host
    Write-Host "Retrieving a list of all resource groups. One moment, please..." -ForegroundColor Yellow
    $resourceGroups = Get-AzResourceGroup
    if ($resourceGroups.Count -eq 0) {
        Write-Host
        Write-Host "No resource groups found in this subscription." -ForegroundColor Yellow
        $createNewRG = "y"
    } else {
        # Display the resource groups in a numbered list
        Write-Host
        Write-Host "Existing resource groups:" -ForegroundColor Cyan
        Write-Host
        for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
            Write-Host "$($i + 1). $($resourceGroups[$i].ResourceGroupName) - Location: $($resourceGroups[$i].Location)"
        }

        # Ask the user for selection
        $validSelection = $false
        while (-not $validSelection) {
            Write-Host
            Write-Host "Select a resource group from the list or type 'new' to create a new resource group: " -ForegroundColor Cyan -NoNewline
            $selection = (Read-Host).ToLower()

            if ($selection -eq 'new') {
                $createNewRG = "y"
                $validSelection = $true
            } elseif ($selection -match '^\d+$' -and [int]$selection -le $resourceGroups.Count -and [int]$selection -gt 0) {
                $resourceGroupName = $resourceGroups[[int]$selection - 1].ResourceGroupName
                $createNewRG = "n"
                $validSelection = $true
            } else {
                Write-Host
                Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            }
        }
    }

    # If the user opts to create a new resource group
    if ($createNewRG -eq "y") {
        Write-Host
        Write-Host "Enter the name for the new Resource Group: " -ForegroundColor Cyan -NoNewline
        $resourceGroupName = Read-Host
        $location = "centralus"  # Default to centralus
        Write-Host
        Write-Host "Creating Resource Group '$resourceGroupName' in 'centralus'..."
        $newRG = New-AzResourceGroup -Name $resourceGroupName -Location $location

        # Ensure the Resource Group was created successfully
        if ($newRG -ne $null) {
            Write-Host
            Write-Host "Resource Group '$resourceGroupName' created successfully." -ForegroundColor Green
        } else {
            Write-Host
            Write-Host "Failed to create Resource Group '$resourceGroupName'." -ForegroundColor Red
            exit
        }
    }

    # Inform the user about Key Vault name restrictions
    Write-Host
    Write-Host "Key Vault name restrictions:" -ForegroundColor Yellow
    Write-Host " - Must be between 3-24 characters in length." -ForegroundColor Yellow
    Write-Host " - Can only contain alphanumeric characters (A-Z, 0-9) and hyphens (-)." -ForegroundColor Yellow
    Write-Host " - No special characters other than hyphens are allowed." -ForegroundColor Yellow
    Write-Host " - Must start with a letter and end with a letter or digit." -ForegroundColor Yellow
    Write-Host " - Must be globally unique." -ForegroundColor Yellow

    # Ask for Key Vault name and validate it
    $validKeyVaultName = $false
    while (-not $validKeyVaultName) {
        Write-Host
        Write-Host "Enter a unique Key Vault name: " -ForegroundColor Cyan -NoNewLine
        $keyVaultName = Read-Host
        $validationMessage = Validate-KeyVaultName -kvName $keyVaultName
        if ($validationMessage) {
            Write-Host
            Write-Host $validationMessage -ForegroundColor Red
        } else {
            $validKeyVaultName = $true
        }
    }

    # Ask if the user wants to enable purge protection
    Write-Host
    Write-Host "Would you like to enable purge protection? (y/n): " -ForegroundColor Cyan -NoNewline
    $enablePurgeProtectionInput = (Read-Host).ToLower()
    $enablePurgeProtection = $enablePurgeProtectionInput -eq 'y' # Convert to Boolean

    # Ask for soft delete retention period (7-90 days)
    $validSoftDeleteRetention = $false
    while (-not $validSoftDeleteRetention) {
        Write-Host
        Write-Host "Enter the soft delete retention period in days (7-90): " -ForegroundColor Cyan -NoNewline
        $softDeleteRetentionPeriod = Read-Host
        if ($softDeleteRetentionPeriod -match '^\d+$' -and [int]$softDeleteRetentionPeriod -ge 7 -and [int]$softDeleteRetentionPeriod -le 90) {
            $validSoftDeleteRetention = $true
        } else {
            Write-Host "Invalid input. Soft delete retention must be a number between 7 and 90." -ForegroundColor Red
        }
    }

    # Call function to create Key Vault
    $kvCreated = CreateKeyVault -keyVaultName $keyVaultName -resourceGroupName $resourceGroupName -softDeleteRetentionPeriod $softDeleteRetentionPeriod -enablePurgeProtection $enablePurgeProtection

    # Only prompt for AKV Owner role assignment if Key Vault was successfully created
    if ($kvCreated) {
        Assign-AKVOwnerRole
    }

    # Ask if the user wants to create another Key Vault
    Write-Host
    Write-Host "Would you like to create another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
    $continue = (Read-Host).ToLower()

} while ($continue -eq 'y')