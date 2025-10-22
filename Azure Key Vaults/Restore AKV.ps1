<#
.SYNOPSIS
Restores secrets and certificates from an Azure Key Vault backup to a specified location.

.DESCRIPTION
- Lists available Key Vaults and prompts the user to select one.
- Validates the backup path and supports group (all items) or single-item restoration.
- Presents a summary of planned actions for confirmation before proceeding.
- Checks required RBAC roles and assigns them if necessary.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.10.15 at 1759 by Joe McLain (joe@bvu.edu)
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
Write-Host "Restore Azure Key Vault..." -ForegroundColor Blue
Write-Host

# Install and import required PowerShell modules
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.KeyVault', 'Az.Accounts', 'Az.Resources')
foreach ($module in $requiredModules) {
    # Check if the module is installed
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

    # Check if the module is already imported
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

# Authenticate to Azure if not already authenticated
if (-not $isAuthenticated) {
    Write-Host
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    try {
        Connect-AzAccount -ErrorAction Stop
        Write-Host "Authentication successful." -ForegroundColor Green
    }
    catch {
        Write-Host "Authentication failed. Error: $_" -ForegroundColor Red
        exit
    }
}

# Function to validate non-blank user input and handle validation for different types (numbers and Y/N)
function Get-ValidatedInput {
    param (
        [string]$promptMessage,
        [string]$errorMessage = "Input cannot be blank. Please enter a valid value.",
        [string[]]$validValues = $null # Use array for valid values
    )

    $inputValue = $null
    do {
        Write-Host $promptMessage -ForegroundColor Cyan -NoNewline
        $inputValue = Read-Host
        if ($validValues) {
            if ($validValues -contains $inputValue) {
                return $inputValue
            } else {
                Write-Host $errorMessage -ForegroundColor Red
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($inputValue)) {
            return $inputValue
        } else {
            Write-Host $errorMessage -ForegroundColor Red
        }
    } while (-not [string]::IsNullOrWhiteSpace($inputValue))
}

# Function to check and assign roles
function Check-AssignRole {
    param (
        [string]$userId,
        [string]$resourceId
    )

    Write-Host
    Write-Host "Checking role assignments for the authenticated user..." -ForegroundColor Yellow

    $requiredRoles = @("Key Vault Secrets Officer", "Key Vault Certificates Officer")
    $hasRequiredRoles = $true

    foreach ($role in $requiredRoles) {
        $roleAssignment = Get-AzRoleAssignment -ObjectId $userId -Scope $resourceId -RoleDefinitionName $role -ErrorAction SilentlyContinue
        if (-not $roleAssignment) {
            Write-Host "The user does not have the required role: $role." -ForegroundColor Red
            $hasRequiredRoles = $false
        }
    }

    if ($hasRequiredRoles) {
        Write-Host "User already has the required roles." -ForegroundColor Green
        return $true
    } else {
        do {
            Write-Host
            Write-Host "Would you like to assign these roles now? (y/n): " -ForegroundColor Cyan -NoNewline
            $assignRoles = (Read-Host).ToLower()
            if ($assignRoles -ne 'y' -and $assignRoles -ne 'n') {
                Write-Host
                Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
            }
        } while ($assignRoles -ne 'y' -and $assignRoles -ne 'n')

        if ($assignRoles -eq 'y') {
            Write-Host
            Write-Host "Assigning the required roles..." -ForegroundColor Yellow
            foreach ($role in $requiredRoles) {
                try {
                    New-AzRoleAssignment -ObjectId $userId -Scope $resourceId -RoleDefinitionName $role -ErrorAction Stop
                    Write-Host "Role '$role' assigned successfully." -ForegroundColor Green
                } catch {
                    if ($_ -match "Conflict") {
                        Write-Host "Conflict encountered: User may already have the role '$role' or a similar issue occurred. Skipping this role assignment." -ForegroundColor Yellow
                    } else {
                        Write-Host "Error assigning role '$role'. Error: $_" -ForegroundColor Red
                    }
                }
            }
            Write-Host "Waiting 15 seconds for propagation..." -ForegroundColor Yellow
            Start-Sleep -Seconds 15
            return $true
        } else {
            Write-Host "Skipping restoration due to insufficient permissions." -ForegroundColor Yellow
            return $false
        }
    }
}

# Function to check and validate the existence of the backup path
function Validate-BackupPath {
    param (
        [string]$backupPath
    )
    if (-not (Test-Path $backupPath)) {
        Write-Host "The backup path does not exist." -ForegroundColor Red
        return $false
    }
    return $true
}

# Function to display the Key Vaults and prompt for selection
function Select-KeyVault {
    do {
        Write-Host
        Write-Host "Retrieving list of Azure Key Vaults..." -ForegroundColor Yellow
        $keyVaults = Get-AzKeyVault | Select-Object -Property VaultName
        $keyVaults += [PSCustomObject]@{ VaultName = "Create New Key Vault" }

        # Display available Key Vaults for selection
        $counter = 1
        foreach ($vault in $keyVaults) {
            Write-Host "$counter. $($vault.VaultName)"
            $counter++
        }

        # Get valid selection from the user
        $selectionIndex = 0
        Write-Host
        do {
            $selectionIndex = Get-ValidatedInput "Please select a Key Vault to restore to: " "Please select a valid number from the list."
            if ($selectionIndex -match '^\d+$' -and $selectionIndex -gt 0 -and $selectionIndex -le $keyVaults.Count) {
                $selectedVault = $keyVaults[$selectionIndex - 1].VaultName
                break
            } else {
                Write-Host "Invalid selection. Please enter a valid number from the list." -ForegroundColor Red
            }
        } while ($true)

        if ($selectedVault -eq "Create New Key Vault") {
            Write-Host
            Write-Host "Starting process to create a new Key Vault..." -ForegroundColor DarkCyan
            & ".\Create AKV.ps1" -isAuthenticated $isAuthenticated

            # Re-run the selection process after creating a new Key Vault
            $selectedVault = $null  # Reset the variable to ensure selection is prompted again
        } else {
            # Return the selected Key Vault if valid
            return $selectedVault
        }

    } while (-not $selectedVault)
}

# Updated Function to restore a selected item
Function Restore-Selected {
    param (
        [Parameter(Mandatory = $true)]
        [string]$selectedVault,
        [Parameter(Mandatory = $true)]
        [string]$backupPath,
        [Parameter(Mandatory = $true)]
        [string]$restoreType,
        [object]$selectedItem
    )

    if ($restoreType -eq '1' -and $selectedItem) {
        # Handle secret restoration based on filename suffix
        if ($selectedItem.Name -like "*.secret.backup") {
            $secretName = [System.IO.Path]::GetFileNameWithoutExtension($selectedItem.Name).Replace(".secret", "")

            Write-Host "Restoring secret '$secretName' from backup file '$($selectedItem.FullName)'" -ForegroundColor Yellow
            try {
                Restore-AzKeyVaultSecret -VaultName $selectedVault -InputFile $selectedItem.FullName -ErrorAction Stop
                Write-Host "Secret '$secretName' restored successfully from $($selectedItem.Name)." -ForegroundColor Green
            } catch {
                Write-Host "Error restoring secret '$secretName'. Error: $_" -ForegroundColor Red
            }
        }
        # Handle certificate restoration based on filename suffix
        elseif ($selectedItem.Name -like "*.cert.backup") {
            $certificateName = [System.IO.Path]::GetFileNameWithoutExtension($selectedItem.Name).Replace(".cert", "")

            Write-Host "Restoring certificate '$certificateName' from backup file '$($selectedItem.FullName)'" -ForegroundColor Yellow
            try {
                Restore-AzKeyVaultCertificate -VaultName $selectedVault -InputFile $selectedItem.FullName -ErrorAction Stop
                Write-Host "Certificate '$certificateName' restored successfully from $($selectedItem.Name)." -ForegroundColor Green
            } catch {
                Write-Host "Error restoring certificate '$certificateName'. Error: $_" -ForegroundColor Red
            }
        } else {
            # This block ensures consistent handling if unsupported file types are encountered
            Write-Host "Unknown file type for restoration: $($selectedItem.Name). Supported file types are: .secret.backup, .cert.backup" -ForegroundColor Red
        }
    } elseif ($restoreType -eq '2') {
        Restore-KeyVaultSecretsAndCerts -keyVaultName $selectedVault -backupPath $backupPath
    }
}

# Function to restore all secrets and certificates from a backup
function Restore-KeyVaultSecretsAndCerts {
    param (
        [Parameter(Mandatory = $true)]
        [string]$keyVaultName,
        [Parameter(Mandatory = $true)]
        [string]$backupPath
    )

    Write-Host "Restoring secrets and certificates to Key Vault '$keyVaultName'..." -ForegroundColor Cyan

    try {
        $secretBackups = Get-ChildItem -Path $backupPath -Filter "*.secret.backup"
        if ($secretBackups) {
            foreach ($backupFile in $secretBackups) {
                $secretName = [System.IO.Path]::GetFileNameWithoutExtension($backupFile.Name).Replace(".secret", "")

                Write-Host "Restoring secret '$secretName' from backup file '$($backupFile.FullName)'" -ForegroundColor Yellow
                try {
                    Restore-AzKeyVaultSecret -VaultName $keyVaultName -InputFile $backupFile.FullName -ErrorAction Stop
                    Write-Host "Secret '$secretName' restored successfully from $($backupFile.Name)." -ForegroundColor Green
                } catch {
                    Write-Host "Error restoring secret '$secretName'. Error: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No secret backups found in path '$backupPath'." -ForegroundColor Yellow
        }

        $certificateBackups = Get-ChildItem -Path $backupPath -Filter "*.cert.backup"
        if ($certificateBackups) {
            foreach ($backupFile in $certificateBackups) {
                $certificateName = [System.IO.Path]::GetFileNameWithoutExtension($backupFile.Name).Replace(".cert", "")

                Write-Host "Restoring certificate '$certificateName' from backup file '$($backupFile.FullName)'" -ForegroundColor Yellow
                try {
                    Restore-AzKeyVaultCertificate -VaultName $keyVaultName -InputFile $backupFile.FullName -ErrorAction Stop
                    Write-Host "Certificate '$certificateName' restored successfully from $($backupFile.Name)." -ForegroundColor Green
                } catch {
                    Write-Host "Error restoring certificate '$certificateName'. Error: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No certificate backups found in path '$backupPath'." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving secrets or certificates during restore: $_" -ForegroundColor Red
    }

    Write-Host "Restore process completed for Key Vault '$keyVaultName'." -ForegroundColor Green
}

# Main Script Flow
do {
    Write-Host

    # Select the Key Vault
    $selectedVault = Select-KeyVault
    if (-not $selectedVault) {
        Write-Host "No valid Key Vault selected. Please select again." -ForegroundColor Red
        continue
    }

        # Ensure RBAC roles are correct for the selected Key Vault
        $userId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account).Id
        $resourceId = (Get-AzKeyVault -VaultName $selectedVault).ResourceId
        $roleCheck = Check-AssignRole -userId $userId -resourceId $resourceId

    # Prompt for backup path and validate it
    do {
        Write-Host
        $backupPath = Get-ValidatedInput "Enter the full path to your recovery files: " "Backup path cannot be empty."
        if (-not (Validate-BackupPath -backupPath $backupPath)) {
            Write-Host "Please enter a valid backup path." -ForegroundColor Red
        }
    } while (-not (Validate-BackupPath -backupPath $backupPath))

    # Ask if the user wants to restore everything or a single item
    Write-Host
    Write-Host "1. Restore a single item" -ForegroundColor Yellow
    Write-Host "2. Restore all items" -ForegroundColor Yellow
    $restoreType = Get-ValidatedInput "Please enter the number of the option you'd like to select: " "Please enter '1' for single or '2' for group." @('1','2')

    if (-not $roleCheck) {
        Write-Host "Cannot proceed without the correct roles. Exiting." -ForegroundColor Red
        break
    }

    # If the user selects to restore a single item, display the list of items
    $selectedItem = $null
    if ($restoreType -eq '1') {
        # List available secrets and certificates
        Write-Host
        Write-Host "Listing available secrets and certificates in the path..." -ForegroundColor Cyan

        # First, get secrets
        $secretBackups = Get-ChildItem -Path $backupPath -Filter "*.secret.backup"
        
        # Then, get certificates
        $certBackups = Get-ChildItem -Path $backupPath -Filter "*.cert.backup"

        # Combine both into a single list
        $backupFiles = $secretBackups + $certBackups

        if ($backupFiles.Count -eq 0) {
            Write-Host "No secrets or certificates found in the backup path." -ForegroundColor Red
            continue
        }

        # Display the files with numbers for selection
        for ($i = 0; $i -lt $backupFiles.Count; $i++) {
            Write-Host "$($i + 1). $($backupFiles[$i].Name)"
        }

        # Ask the user to select a file to restore
        $fileSelection = Get-ValidatedInput "Please select a file by number to restore: " "Please enter a valid number." 
        if ($fileSelection -match '^\d+$' -and [int]$fileSelection -gt 0 -and [int]$fileSelection -le $backupFiles.Count) {
            $selectedItem = $backupFiles[[int]$fileSelection - 1]
        } else {
            Write-Host "Invalid selection. Please select a valid number." -ForegroundColor Red
            continue
        }
    }

    # Display summary of actions based on the restore type
    Write-Host
    Write-Host "Summary of actions:" -ForegroundColor Cyan
    Write-Host "Key Vault: $selectedVault" -ForegroundColor DarkBlue
    Write-Host "Backup Path: $backupPath" -ForegroundColor DarkBlue
    if ($restoreType -eq '1') {
        Write-Host "Action: Restore a single item." -ForegroundColor DarkBlue
        Write-Host "Item: $($selectedItem.Name)" -ForegroundColor DarkBlue
    } else {
        Write-Host "Action: Restore all secrets and certificates in the backup path." -ForegroundColor DarkBlue
    }

# Confirmation before proceeding
$proceed = Get-ValidatedInput "Would you like to proceed with the restoration (Y/N)? " "Please enter 'Y' or 'N'." @('Y','N')

if ($proceed.ToLower() -eq 'y') {
    # Call the Restore-Selected function if the user chooses to proceed
    Restore-Selected -selectedVault $selectedVault -backupPath $backupPath -restoreType $restoreType -selectedItem $selectedItem
} 
elseif ($proceed.ToLower() -eq 'n') {
    Write-Host "Action canceled by user." -ForegroundColor DarkCyan
}

# Ask if the user wants to perform another restore action
Write-Host
$continue = Get-ValidatedInput "Would you like to perform another restore action (Y/N)? " "Please enter 'Y' or 'N'." @('Y','N')

} while ($continue.ToLower() -eq 'y')