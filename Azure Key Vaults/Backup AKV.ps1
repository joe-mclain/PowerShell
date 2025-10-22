<#
.SYNOPSIS
Backs up secrets and certificates from an Azure Key Vault to a local folder with clear filename extensions.

.DESCRIPTION
- Retrieves the list of Azure Key Vaults.
- Prompts the user to select a Key Vault.
- Backs up all items to a local folder:
  - Secrets saved as *.secret.backup
  - Certificates saved as *.cert.backup
- Checks for required RBAC roles and assigns them if needed.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.11 at 1355 by Joe McLain (joe@bvu.edu)
#>

param (
    [switch]$isAuthenticated
)

Write-Host
Write-Host "Backup Azure Key Vault..." -ForegroundColor Blue
Write-Host

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Import the required modules if not already available
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.KeyVault', 'Az.Accounts', 'Az.Resources')
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

if (-not $isAuthenticated) {
    Write-Host
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    Connect-AzAccount -ErrorAction Stop
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
            Write-Host "Skipping backup due to insufficient permissions." -ForegroundColor Yellow
            return $false
        }
    }
}

function Backup-KeyVaultSecretsAndCerts {
    param (
        [Parameter(Mandatory = $true)]
        [string] $keyVaultName,
        [Parameter(Mandatory = $true)]
        [string] $backupPath
    )

    Write-Host
    Write-Host "Retrieving secrets from Key Vault '$keyVaultName'..." -ForegroundColor Cyan
    try {
        # Backup all secrets without filtering based on ContentType
        $secrets = Get-AzKeyVaultSecret -VaultName $keyVaultName -ErrorAction Stop
        if ($secrets) {
            foreach ($secret in $secrets) {
                $secretName = $secret.Name
                $backupFilePath = Join-Path -Path $backupPath -ChildPath "$secretName.secret.backup"
                Write-Host "Backing up secret '$secretName'..." -ForegroundColor Yellow
                try {
                    Backup-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -OutputFile $backupFilePath -ErrorAction Stop
                    Write-Host "Secret '$secretName' backed up successfully in $backupFilePath." -ForegroundColor Green
                } catch {
                    Write-Host "Error backing up secret '$secretName'. Error: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No secrets found in Key Vault '$keyVaultName'." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving secrets: $_" -ForegroundColor Red
    }

    Write-Host
    Write-Host "Retrieving certificates from Key Vault '$keyVaultName'..." -ForegroundColor Cyan
    try {
        # Backup certificates separately
        $certificates = Get-AzKeyVaultCertificate -VaultName $keyVaultName -ErrorAction Stop
        if ($certificates) {
            foreach ($certificate in $certificates) {
                $certificateName = $certificate.Name
                $backupFilePath = Join-Path -Path $backupPath -ChildPath "$certificateName.cert.backup"
                Write-Host "Backing up certificate '$certificateName'..." -ForegroundColor Yellow
                try {
                    Backup-AzKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName -OutputFile $backupFilePath -ErrorAction Stop
                    Write-Host "Certificate '$certificateName' backed up successfully in $backupFilePath." -ForegroundColor Green
                } catch {
                    Write-Host "Error backing up certificate '$certificateName'. Error: $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "No certificates found in Key Vault '$keyVaultName'." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error retrieving certificates: $_" -ForegroundColor Red
    }
}

# Main loop for selecting Key Vaults and performing backup
do {
    Write-Host
    Write-Host "Retrieving the list of Azure Key Vaults..." -ForegroundColor Cyan
    try {
        $keyVaults = Get-AzKeyVault -ErrorAction Stop
    } catch {
        Write-Host "Error retrieving Key Vaults: $_" -ForegroundColor Red
        exit
    }

    if (-not $keyVaults) {
        Write-Host
        Write-Host "No Key Vaults found in the subscription." -ForegroundColor Red
        exit
    }

    for ($i = 0; $i -lt $keyVaults.Count; $i++) {
        Write-Host "$($i + 1). $($keyVaults[$i].VaultName) in $($keyVaults[$i].ResourceGroupName)"
    }

    $inputValid = $false
    do {
        Write-Host
        Write-Host "Enter the number of the Key Vault to backup: " -ForegroundColor Cyan -NoNewline
        $selection = Read-Host

        if ($selection -eq '') {
            Write-Host
            Write-Host "Input cannot be empty. Please enter a valid number." -ForegroundColor Red
        } elseif ($selection -match '^\d+$' -and [int]$selection -gt 0 -and [int]$selection -le $keyVaults.Count) {
            $keyVault = $keyVaults[[int]$selection - 1]
            $keyVaultName = $keyVault.VaultName
            $resourceId = $keyVault.ResourceId

            if ($null -eq $keyVault) {
                Write-Host
                Write-Host "Selected Key Vault is invalid or not found." -ForegroundColor Red
                exit
            } else {
                Write-Host "Selected Key Vault: $keyVaultName" -ForegroundColor Green
                $inputValid = $true
            }
        } else {
            Write-Host
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        }
    } while (-not $inputValid)

    # Path input loop
    do {
        Write-Host
        Write-Host "Enter the path for the backup files: " -ForegroundColor Cyan -NoNewline
        $backupPath = Read-Host
    
        # Validate path and directory existence
        $validPathPattern = '^[a-zA-Z]:\\[^<>:"/|?*]+(?:\\[^<>:"/|?*]+)*$'
        if ($backupPath -eq '') {
            Write-Host
            Write-Host "Input cannot be empty. Please enter a valid path." -ForegroundColor Red
            $inputValid = $false
        } elseif ($backupPath -notmatch $validPathPattern) {
            Write-Host
            Write-Host "The folder path contains invalid characters or format. Please enter a valid path (e.g., C:\\folder\\subfolder)." -ForegroundColor Red
            $inputValid = $false
        } else {
            # If path is valid, ensure directory exists or handle creation
            if (-not (Test-Path -Path $backupPath)) {
                do {
                    Write-Host
                    Write-Host "The folder path does not exist. Would you like to create it? (y/n): " -ForegroundColor Cyan -NoNewline
                    $createPath = (Read-Host).ToLower()
                    if ($createPath -ne 'y' -and $createPath -ne 'n') {
                        Write-Host
                        Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
                    }
                } while ($createPath -ne 'y' -and $createPath -ne 'n')

                if ($createPath -eq 'y') {
                    try {
                        New-Item -ItemType Directory -Path $backupPath -Force
                        Write-Host "Directory created." -ForegroundColor Green
                        $inputValid = $true
                    } catch {
                        Write-Host "Failed to create directory: $_" -ForegroundColor Red
                        $inputValid = $false
                    }
                } else {
                    Write-Host "Please enter a valid path." -ForegroundColor Red
                    $inputValid = $false
                }
            } else {
                # Check to see if directory has any contents
                $folderContents = Get-ChildItem -Path $backupPath
                if ($folderContents.Count -gt 0) {
                    do {
                        Write-Host
                        Write-Host "The path is not empty. Would you like to see a list of the contents? (y/n): " -ForegroundColor Cyan -NoNewline
                        $seeContents = (Read-Host).ToLower()
                        if ($seeContents -ne 'y' -and $seeContents -ne 'n') {
                            Write-Host
                            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
                        }
                    } while ($seeContents -ne 'y' -and $seeContents -ne 'n')

                    if ($seeContents -eq 'y') {
                        Get-ChildItem -Path $backupPath | Format-Table LastWriteTime, Length, Name -AutoSize
                    }

                    do {
                        Write-Host
                        Write-Host "Would you like to delete the contents of the folder? (y/n): " -ForegroundColor Cyan -NoNewline
                        $deleteContents = (Read-Host).ToLower()
                        if ($deleteContents -ne 'y' -and $deleteContents -ne 'n') {
                            Write-Host
                            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
                        }
                    } while ($deleteContents -ne 'y' -and $deleteContents -ne 'n')

                    if ($deleteContents -eq 'y') {
                        try {
                            Remove-Item -Path $backupPath\* -Recurse -Force
                            Write-Host
                            Write-Host "Contents deleted." -ForegroundColor Green
                            $inputValid = $true
                        } catch {
                            Write-Host "Failed to delete contents: $_" -ForegroundColor Red
                            $inputValid = $false
                        }
                    } else {
                        Write-Host
                        Write-Host "Please select a different folder." -ForegroundColor Red
                        $inputValid = $false
                    }
                } else {
                    Write-Host "The directory exists and is empty. Proceeding..." -ForegroundColor Green
                    $inputValid = $true
                }
            }
        }

    } while (-not $inputValid)

    # Present summary and request confirmation before proceeding
    Write-Host
    Write-Host "Summary of actions to be performed:" -ForegroundColor DarkBlue
    Write-Host "1. Secrets and certificates from the Key Vault '$keyVaultName' will be backed up." -ForegroundColor DarkBlue
    Write-Host "2. Regular secrets will be backed up with a '.secret.backup' extension." -ForegroundColor DarkBlue
    Write-Host "3. Certificates will be backed up with a '.cert.backup' extension." -ForegroundColor DarkBlue
    Write-Host "4. The backup files will be saved in the folder: '$backupPath'." -ForegroundColor DarkBlue
    Write-Host

    $inputValid = $false
    do {
        Write-Host "Do you want to proceed with the backup? (y/n): " -ForegroundColor Cyan -NoNewline
        $proceed = (Read-Host).ToLower()

        if ($proceed -eq 'y' -or $proceed -eq 'n') {
            $inputValid = $true
        } else {
            Write-Host
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
        }
    } while (-not $inputValid)

    # Check to see if the user decided to proceed with the backup
    if ($proceed -eq 'y') {
        # Perform backup
        $userId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account).Id
        $roleCheck = Check-AssignRole -userId $userId -resourceId $resourceId

        if ($roleCheck) {
            Backup-KeyVaultSecretsAndCerts -keyVaultName $keyVaultName -backupPath $backupPath
        } else {
            Write-Host
            Write-Host "Skipping backup due to insufficient permissions." -ForegroundColor Yellow
        }
    } else {
        Write-Host
        Write-Host "Backup operation skipped by the user." -ForegroundColor Yellow
    }

    # Ask if the user would like to perform another backup
    $inputValid = $false
    do {
        Write-Host
        Write-Host "Would you like to backup another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $continue = (Read-Host).ToLower()

        if ($continue -eq 'y' -or $continue -eq 'n') {
            $inputValid = $true
        } else {
            Write-Host
            Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
        }
    } while (-not $inputValid)

} while ($continue -eq 'y')