<#
.SYNOPSIS
Manages Azure Key Vault ownership and RBAC assignments for specified users.

.DESCRIPTION
1. Allow the user to view assigned roles for a user within a specific Azure Key Vault.
2. Allow the user to add owners for the selected Key Vault using the following roles:
    - Owner
    - Key Vault Administrator
    - Key Vault Certificates Officer
3. Allow the user to remove owners for the selected Key Vault using the following roles:
    - Owner
    - Key Vault Administrator
    - Key Vault Certificates Officer
    - Key Vault Secrets Officer
    - Key Vault Reader
4. Allow the user to list the RBAC permissions for a specific user on the selected Key Vault.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.26 at 1052 by Joe McLain (joe@bvu.edu)
#>

param (
    [switch]$isAuthenticated
)

Write-Host
Write-Host "Change Ownership of an Azure Key Vault..." -ForegroundColor Blue
Write-Host

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# RBAC role definitions to add or remove
$rolesToRemove = @("Owner", "Key Vault Administrator", "Key Vault Certificates Officer", "Key Vault Secrets Officer", "Key Vault Reader")
$rolesToAdd = @("Owner", "Key Vault Administrator", "Key Vault Certificates Officer")

# Install and import required PowerShell modules
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.Resources', 'Az.KeyVault')
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

# Main loop for action choices
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
    
    # Get the user's selection for a specific key vault
    $inputValid = $false
    do {
        Write-Host
        Write-Host "Select the desired key vault by number: " -ForegroundColor Cyan -NoNewline
        $selectedIndex = Read-Host
        try {
            $selectedIndex = [int]$selectedIndex
            if ($selectedIndex -gt 0 -and $selectedIndex -le $keyVaults.Count) {
                $inputValid = $true
            } else {
                Write-Host
                Write-Host "Invalid selection. Please enter a number between 1 and $($keyVaults.Count)." -ForegroundColor Red
            }
        } catch {
            Write-Host
            Write-Host "Invalid input. Please enter a valid number." -ForegroundColor Red
        }
    } while (-not $inputValid)

    # Set the selected Key Vault and its scope
    $selectedKeyVault = $keyVaults[$selectedIndex - 1]
    $scope = $selectedKeyVault.ResourceId

    # Ask the user what action they want to perform
    $inputValid = $false
    do {
        Write-Host
        Write-Host "What action would you like to perform?" -ForegroundColor Cyan
        Write-Host "1. List RBAC Permissions"
        Write-Host "2. Add Owner"
        Write-Host "3. Remove Owner"
        Write-Host "Please enter the number of your desired action: " -ForegroundColor Cyan -NoNewline
        $actionChoice = Read-Host
        switch ($actionChoice) {
            1 {
                $actionType = 'list'
                $inputValid = $true
            }
            2 {
                $actionType = 'add'
                $inputValid = $true
            }
            3 {
                $actionType = 'remove'
                $inputValid = $true
            }
            default {
                Write-Host
                Write-Host "Invalid input. Please select 1, 2, or 3." -ForegroundColor Red
                $inputValid = $false
            }
        }
    } while (-not $inputValid)

    if ($actionChoice -eq 1) {
        # List all owners and their roles, both inherited and explicit
        $inputValid = $false
        do {
            Write-Host
            Write-Host "Enter the UPN of the user to check RBAC permissions: " -ForegroundColor Cyan -NoNewline
            $ownerUPN = Read-Host
            try {
                # Retrieve the user object to verify existence
                $user = Get-AzADUser -UserPrincipalName $ownerUPN -ErrorAction Stop
                if ($null -eq $user) {
                    throw "The UPN '$ownerUPN' does not exist. Please try again."
                }

                Write-Host "The UPN '$ownerUPN' has been found." -ForegroundColor Green
                
                $roleAssignments = Get-AzRoleAssignment -ObjectId $user.Id -Scope $scope
                if ($roleAssignments) {
                    Write-Host
                    Write-Host "Listing RBAC permissions for user '$($user.UserPrincipalName)' in Key Vault '$($selectedKeyVault.VaultName)'..." -ForegroundColor Cyan
                    foreach ($assignment in $roleAssignments) {
                        $inherited = if ($assignment.Scope -ne $scope) { "(Inherited)" } else { "(Explicit)" }
                        Write-Host "$($user.DisplayName) has role $($assignment.RoleDefinitionName) $inherited." -ForegroundColor Blue
                    }
                } else {
                    Write-Host "No role assignments found for $($user.UserPrincipalName) in Key Vault '$($selectedKeyVault.VaultName)'." -ForegroundColor Yellow
                }
                $inputValid = $true
            } catch {
                Write-Host
                Write-Host "Invalid UPN. Please try again." -ForegroundColor Red
            }
        } while (-not $inputValid)
    }

    if ($actionChoice -eq 2) {
        # Add Owner Section
        $exitLoop = $false
        do {
            Write-Host
            Write-Host "Enter the UPN of the new owner: " -ForegroundColor Cyan -NoNewline
            $ownerUPN = Read-Host

            try {
                # Retrieve the user object to verify existence
                $user = Get-AzADUser -UserPrincipalName $ownerUPN -ErrorAction Stop
                if ($null -eq $user) {
                    throw "The UPN '$ownerUPN' does not exist. Please try again."
                }

                Write-Host
                Write-Host "The UPN '$ownerUPN' has been found." -ForegroundColor Green

                # Get existing roles for the user
                $existingRoles = Get-AzRoleAssignment -ObjectId $user.Id -Scope $scope

                # Add only roles not already assigned
                $rolesToAssign = $rolesToAdd | Where-Object { -not ($existingRoles.RoleDefinitionName -contains $_) }
                if ($rolesToAssign.Count -eq 0) {
                    Write-Host "All selected roles are already assigned to the user." -ForegroundColor Green
                    $exitLoop = $true
                    break
                }

                Write-Host "The following roles will be assigned: $($rolesToAssign -join ', ')." -ForegroundColor Blue

                # Politely ask if the user wants to proceed
                Write-Host
                Write-Host "Would you like to proceed? (Y/N): " -ForegroundColor Cyan -NoNewline
                $confirmAction = (Read-Host).ToLower()
                if ($confirmAction -eq 'y') {
                    foreach ($role in $rolesToAssign) {
                        try {
                            Write-Host "Attempting to assign role '$role' to $ownerUPN..." -ForegroundColor Blue
                            New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $role -Scope $scope -ErrorAction Stop | Out-Null
                            Write-Host "Successfully assigned role '$role' to $ownerUPN." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to assign role '$role' to '$ownerUPN'. Error: $_" -ForegroundColor Red
                        }
                    }
                    $exitLoop = $true
                } else {
                    Write-Host "Action cancelled." -ForegroundColor Red
                    $exitLoop = $true
                    break
                }
            } catch {
                Write-Host
                Write-Host "Error: $_" -ForegroundColor Red
                Write-Host "The UPN '$ownerUPN' is not valid. Please try again." -ForegroundColor Red
            }
        } while (-not $inputValid -and -not $exitLoop)
    }

    if ($actionChoice -eq 3) {
        # Remove Owner Section
        $exitLoop = $false
        do {
            Write-Host
            Write-Host "Enter the UPN of the owner to remove: " -ForegroundColor Cyan -NoNewline
            $ownerUPN = Read-Host
    
            try {
                # Retrieve the user object to verify existence
                $user = Get-AzADUser -UserPrincipalName $ownerUPN -ErrorAction Stop
                if ($null -eq $user) {
                    throw "The UPN '$ownerUPN' does not exist. Please try again."
                }
    
                Write-Host
                Write-Host "The UPN '$ownerUPN' has been found." -ForegroundColor Green
    
                # Get existing roles for the user
                $existingRoles = Get-AzRoleAssignment -ObjectId $user.Id -Scope $scope
    
                # Filter out inherited roles, keep only explicit ones
                $explicitRoles = $existingRoles | Where-Object { $_.Scope -eq $scope }
                $rolesToRemoveExplicit = $rolesToRemove | Where-Object { $_ -in $explicitRoles.RoleDefinitionName }
    
                if ($rolesToRemoveExplicit.Count -eq 0) {
                    Write-Host "The user does not have any of the selected roles to remove." -ForegroundColor Green
                    $exitLoop = $true
                    break
                }
    
                Write-Host "The following roles will be removed: $($rolesToRemoveExplicit -join ', ')." -ForegroundColor Blue
    
                # Politely ask if the user wants to proceed
                Write-Host
                Write-Host "Would you like to proceed? (Y/N): " -ForegroundColor Cyan -NoNewline
                $confirmAction = (Read-Host).ToLower()
                if ($confirmAction -eq 'y') {
                    foreach ($role in $rolesToRemoveExplicit) {
                        try {
                            Write-Host "Attempting to remove role '$role' from $ownerUPN..." -ForegroundColor Blue
                            Remove-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $role -Scope $scope -ErrorAction Stop | Out-Null
                            Write-Host "Successfully removed role '$role' from $ownerUPN." -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to remove role '$role' from '$ownerUPN'. Error: $_" -ForegroundColor Red
                        }
                    }
                    $exitLoop = $true
                } else {
                    Write-Host "Action cancelled." -ForegroundColor Red
                    $exitLoop = $true
                }
            } catch {
                Write-Host
                Write-Host "Error: $_" -ForegroundColor Red
                Write-Host "The UPN '$ownerUPN' is not valid. Please try again." -ForegroundColor Red
            }
        } while (-not $exitLoop)
    }   

    # Ask if the user wants to perform another action or exit
    $inputValid = $false
    do {
        Write-Host
        Write-Host "Would you like to perform another ownership action on a Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $continueChoice = (Read-Host).ToLower()
        if ($continueChoice -eq 'y' -or $continueChoice -eq 'n') {
            $inputValid = $true
        } else {
            Write-Host "Invalid input. Please enter 'y' for yes or 'n' for no." -ForegroundColor Red
        }
    } while (-not $inputValid)

} while ($continueChoice -eq 'y')