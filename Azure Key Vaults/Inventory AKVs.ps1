<#
.SYNOPSIS
Inventories Azure Key Vaults and optionally lists secrets and certificates.

.DESCRIPTION
- Provides a list of all Key Vaults.
- Offers to list secrets.
- Offers to list certificates.
- Lists secrets and/or certificates in a selected vault or in all vaults based on user input.

.NOTES
- Created 2024.09.04 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.11 at 1030 by Joe McLain (joe@bvu.edu)
#>

# Define the parameter that determines whether this script is being called by a control script
param (
    [switch]$isAuthenticated
)

Write-Host
Write-Host "Inventory contents of an Azure Key Vault..." -ForegroundColor Blue
Write-Host

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Import the required Az modules if not already available
if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
    Install-Module -Name Az.KeyVault -Force
}
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Install-Module -Name Az.Accounts -Force
}

# If authentication hasn't been handled by the control script, authenticate
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    Connect-AzAccount -ErrorAction Stop
}

# Ensure that there are key vaults in the subscription
Write-Host
Write-Host "Retrieving the list of Azure Key Vaults..." -ForegroundColor Cyan
$results = Get-AzKeyVault
if (-not $results) {
    Write-Host
    Write-Host "No Key Vaults found in the subscription." -ForegroundColor Red
    exit
}

# Initialize repeat flag
do {
    # Display the list of key vaults in a numbered list
    for ($i = 0; $i -lt $results.Count; $i++) {
        Write-Host "$($i + 1). $($results[$i].VaultName) in $($results[$i].ResourceGroupName)"
    }

    # Ask the user to select a Key Vault or inventory all vaults
    $inputValid = $false
    do {
        Write-Host
        Write-Host "Select a Key Vault from the list or type 'all' to inventory all Key Vaults: " -ForegroundColor Cyan -NoNewline
        $selection = (Read-Host).ToLower()

        if ($selection -eq 'all') {
            # List secrets and certificates for all key vaults
            foreach ($kv in $results) {
                Write-Host
                Write-Host "Secrets in Key Vault: $($kv.VaultName)" -ForegroundColor Cyan
                try {
                    $secrets = Get-AzKeyVaultSecret -VaultName $kv.VaultName -ErrorAction SilentlyContinue
                    if ($secrets -and $secrets.Count -gt 0) {
                        $secrets | Sort-Object -Property Name | ForEach-Object { Write-Host $_.Name }
                    } else {
                        Write-Host "No secrets found in $($kv.VaultName)." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "Error retrieving secrets for $($kv.VaultName). Error: $_" -ForegroundColor Red
                }

                Write-Host
                Write-Host "Certificates in Key Vault: $($kv.VaultName)" -ForegroundColor Cyan
                try {
                    $certificates = Get-AzKeyVaultCertificate -VaultName $kv.VaultName -ErrorAction SilentlyContinue
                    if ($certificates -and $certificates.Count -gt 0) {
                        $certificates | Sort-Object -Property Name | ForEach-Object { Write-Host $_.Name }
                    } else {
                        Write-Host "No certificates found in $($kv.VaultName)." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "Error retrieving certificates for $($kv.VaultName). Error: $_" -ForegroundColor Red
                }
            }
            $inputValid = $true
        } elseif ($selection -match '^\d+$' -and [int]$selection -gt 0 -and [int]$selection -le $results.Count) {
            # Get the user's selection for a specific key vault
            $selectedIndex = [int]$selection - 1
            $selectedKeyVault = $results[$selectedIndex]

            Write-Host
            Write-Host "Secrets in Key Vault: $($selectedKeyVault.VaultName)" -ForegroundColor Cyan
            try {
                $secrets = Get-AzKeyVaultSecret -VaultName $selectedKeyVault.VaultName -ErrorAction SilentlyContinue
                if ($secrets -and $secrets.Count -gt 0) {
                    $secrets | Sort-Object -Property Name | ForEach-Object { Write-Host $_.Name }
                } else {
                    Write-Host "No secrets found in $($selectedKeyVault.VaultName)." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error retrieving secrets for $($selectedKeyVault.VaultName). Error: $_" -ForegroundColor Red
            }

            Write-Host
            Write-Host "Certificates in Key Vault: $($selectedKeyVault.VaultName)" -ForegroundColor Cyan
            try {
                $certificates = Get-AzKeyVaultCertificate -VaultName $selectedKeyVault.VaultName -ErrorAction SilentlyContinue
                if ($certificates -and $certificates.Count -gt 0) {
                    $certificates | Sort-Object -Property Name | ForEach-Object { Write-Host $_.Name }
                } else {
                    Write-Host "No certificates found in $($selectedKeyVault.VaultName)." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error retrieving certificates for $($selectedKeyVault.VaultName). Error: $_" -ForegroundColor Red
            }
            $inputValid = $true
        } else {
            Write-Host
            Write-Host "Invalid input. Please enter a valid number or 'all' to inventory all Key Vaults." -ForegroundColor Red
        }
    } while (-not $inputValid)

    # Ask if the user wants to inventory another vault
    do {
        Write-Host
        Write-Host "Would you like to inventory another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $anotherInventory = (Read-Host).ToLower()

        switch ($anotherInventory) {
            'y' {
                $repeat = $true
                $inputValid = $true
            }
            'n' {
                $repeat = $false
                $inputValid = $true
            }
            default {
                Write-Host
                Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Red
                $inputValid = $false
            }
        }
    } while (-not $inputValid)

} while ($repeat)