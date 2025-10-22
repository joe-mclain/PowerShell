<#
.SYNOPSIS
Manages firewall and virtual network (VNet) settings for an Azure Key Vault.

.DESCRIPTION
- Lists available Key Vaults for selection.
- Enables or disables the Key Vault firewall and shows current firewall status.
- Views existing VNet assignments.
- Adds or removes VNet assignments for the selected Key Vault.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.14 at 1635 by Joe McLain (joe@bvu.edu)
#>

param (
    [switch]$isAuthenticated
)

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

Write-Host
Write-Host "Manage Azure Key Vault Firewall and VNet Settings..." -ForegroundColor Blue
Write-Host

# Import the required Az modules if not already available
$requiredModules = @('Az.KeyVault', 'Az.Network')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module..." -ForegroundColor Cyan
        try {
            Install-Module -Name $module -Force -AllowClobber -ErrorAction Stop
        } catch {
            Write-Host "Failed to install module $module. Error: $_" -ForegroundColor Red
            exit
        }
    }
    try {
        Write-Host "Importing module: $module..." -ForegroundColor Cyan
        Import-Module -Name $module -ErrorAction Stop
    } catch {
        Write-Host "Failed to import module $module. Error: $_" -ForegroundColor Red
        exit
    }
}

# Authenticate to Azure if not already authenticated
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    try {
        Connect-AzAccount -ErrorAction Stop
    } catch {
        Write-Host "Failed to authenticate to Azure. Error: $_" -ForegroundColor Red
        exit
    }
}

# Function to list available Key Vaults
function List-KeyVaults {
    Write-Host
    try {
        $keyVaults = Get-AzKeyVault -ErrorAction Stop
        if (-not $keyVaults) {
            Write-Host "No Key Vaults found in the subscription." -ForegroundColor Red
            return $null
        }

        Write-Host "Available Key Vaults..." -ForegroundColor Blue
        for ($i = 0; $i -lt $keyVaults.Count; $i++) {
            Write-Host "$($i + 1). $($keyVaults[$i].VaultName) in Resource Group: $($keyVaults[$i].ResourceGroupName)"
        }

        return $keyVaults
    } catch {
        Write-Host "Failed to retrieve Key Vaults. Error: $_" -ForegroundColor Red
        return $null
    }
}

# Function to list the firewall status of Key Vaults
function List-FirewallStatus {
    try {
        $keyVaults = Get-AzKeyVault -ErrorAction Stop
        if (-not $keyVaults) {
            Write-Host "No Key Vaults found in the subscription." -ForegroundColor Red
            return
        }

        Write-Host
        Write-Host "Key Vault Firewall Status:" -ForegroundColor Blue
        foreach ($kv in $keyVaults) {
            try {
                # Explicitly refresh key vault properties
                $refreshedKV = Get-AzKeyVault -VaultName $kv.VaultName -ResourceGroupName $kv.ResourceGroupName -ErrorAction Stop
                $status = if ($refreshedKV.PublicNetworkAccess -eq 'Disabled') { "Enabled" } else { "Disabled" }
                $color = if ($status -eq "Enabled") { 'Green' } else { 'Yellow' }
                Write-Host "Key Vault: $($refreshedKV.VaultName) - Firewall: $status" -ForegroundColor $color
            } catch {
                Write-Host "Failed to retrieve status for Key Vault $($kv.VaultName). Error: $_" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "Failed to retrieve Key Vault firewall status. Error: $_" -ForegroundColor Red
    }
}

# Function to manage firewall settings
function Manage-Firewall {
    param (
        [string]$keyVaultName
    )

    try {
        # Lookup the resource group for the specified Key Vault
        $keyVault = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction Stop
        $resourceGroupName = $keyVault.ResourceGroupName

        if (-not $resourceGroupName) {
            Write-Host "Failed to retrieve the resource group for Key Vault '$keyVaultName'. Operation canceled." -ForegroundColor Red
            return
        }

        # Present options to enable/disable firewall
        Write-Host
        Write-Host "1. Enable Firewall"
        Write-Host "2. Disable Firewall"
        Write-Host "Enter the number of the action you wish to take: " -ForegroundColor Cyan -NoNewline
        $action = Read-Host
        if (-not ($action -eq '1' -or $action -eq '2')) {
            Write-Host "Invalid option selected. Operation canceled." -ForegroundColor Red
            return
        }

        if ($action -eq '1') {
            Write-Host
            Write-Host "You have opted to enable the firewall for Key Vault '$keyVaultName'." -ForegroundColor Blue
            Write-Host "This will block public access." -ForegroundColor Blue
            Write-Host "Do you wish to proceed? (y/n): " -ForegroundColor Cyan -NoNewline
            $confirm = Read-Host
            if ($confirm -eq 'y') {
                try {
                    Update-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -PublicNetworkAccess Disabled -ErrorAction Stop
                    Write-Host "Firewall enabled for Key Vault '$keyVaultName'." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to enable firewall for Key Vault '$keyVaultName'. Error: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Operation canceled." -ForegroundColor Yellow
            }
        } elseif ($action -eq '2') {
            Write-Host
            Write-Host "You have opted to disable the firewall for Key Vault '$keyVaultName'." -ForegroundColor Blue
            Write-Host "This will allow public access." -ForegroundColor Blue
            Write-Host "Do you wish to proceed? (y/n): " -ForegroundColor Cyan -NoNewline
            $confirm = Read-Host
            if ($confirm -eq 'y') {
                try {
                    Update-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -PublicNetworkAccess Enabled -ErrorAction Stop
                    Write-Host "Firewall disabled for Key Vault '$keyVaultName'." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to disable firewall for Key Vault '$keyVaultName'. Error: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Operation canceled." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "Failed to manage firewall. Error: $_" -ForegroundColor Red
    }
}

# Function to view VNet assignments for a selected Key Vault
function View-VNetAssignments {
    param (
        [string]$keyVaultName
    )

    try {
        # Lookup the resource group for the specified Key Vault
        $keyVault = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction Stop
        $resourceGroupName = $keyVault.ResourceGroupName

        # Retrieve network rule set details
        $networkRuleSet = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -ErrorAction Stop

        if (-not $networkRuleSet.NetworkAcls.VirtualNetworkRules) {
            Write-Host "No VNets have been assigned access to the Key Vault '$keyVaultName'." -ForegroundColor Yellow
            return
        }

        Write-Host "VNet Assignments for Key Vault '$keyVaultName':" -ForegroundColor DarkCyan
        foreach ($rule in $networkRuleSet.NetworkAcls.VirtualNetworkRules) {
            Write-Host "VNet Resource ID: $($rule.VirtualNetworkResourceId)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to retrieve VNet assignments. Error: $_" -ForegroundColor Red
    }
}

# Function to manage VNet access for a selected Key Vault
function Manage-VNetAccess {
    param (
        [string]$keyVaultName
    )

    try {
        # Lookup the resource group for the specified Key Vault
        $keyVault = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction Stop
        $resourceGroupName = $keyVault.ResourceGroupName

        # List available VNets
        $vnetList = Get-AzVirtualNetwork -ErrorAction Stop
        if (-not $vnetList) {
            Write-Host "No VNets found in the subscription." -ForegroundColor Red
            return
        }

        Write-Host
        Write-Host "Available VNets..." -ForegroundColor Blue
        for ($i = 0; $i -lt $vnetList.Count; $i++) {
            Write-Host "$($i + 1). $($vnetList[$i].Name) in Resource Group: $($vnetList[$i].ResourceGroupName)"
        }

        # Prompt user to select a VNet
        Write-Host "Enter the number of the VNet to manage access for: " -ForegroundColor Cyan -NoNewline
        $vnetSelection = Read-Host
        if (-not ($vnetSelection -match '^\d+$') -or [int]$vnetSelection -le 0 -or [int]$vnetSelection -gt $vnetList.Count) {
            Write-Host "Invalid selection. Operation canceled." -ForegroundColor Red
            return
        }

        $selectedVNet = $vnetList[[int]$vnetSelection - 1]
        
        # Ask if access should be granted or denied using numbered options
        Write-Host
        Write-Host "Access options..." -ForegroundColor Blue
        Write-Host "1. Grant access"
        Write-Host "2. Deny access"
        Write-Host "Enter the number of the action you wish to take: " -ForegroundColor Cyan -NoNewline
        $vnetAction = Read-Host
        if (-not ($vnetAction -eq '1' -or $vnetAction -eq '2')) {
            Write-Host "Invalid selection. Please enter 1 to grant access or 2 to deny access." -ForegroundColor Red
            return
        }

        if ($vnetAction -eq '1') {
            Write-Host
            Write-Host "Granting access to VNet '$($selectedVNet.Name)' for Key Vault '$keyVaultName'..." -ForegroundColor Blue
            Write-Host "Do you wish to proceed? (y/n): " -ForegroundColor Cyan -NoNewline
            $confirm = Read-Host
            if ($confirm -eq 'y') {
                try {
                    # Ensure the selected VNet has a subnet identifier
                    $subnets = $selectedVNet.Subnets
                    if (-not $subnets -or $subnets.Count -eq 0) {
                        Write-Host "No subnets found for the selected VNet. Cannot grant access." -ForegroundColor Red
                        return
                    }

                    # Prompt user to select a subnet
                    Write-Host "Available Subnets for VNet '$($selectedVNet.Name)':" -ForegroundColor DarkCyan
                    for ($j = 0; $j -lt $subnets.Count; $j++) {
                        Write-Host "$($j + 1). $($subnets[$j].Name)"
                    }
                    Write-Host "Enter the number of the subnet to grant access to: " -ForegroundColor Cyan -NoNewline
                    $subnetSelection = Read-Host
                    if (-not ($subnetSelection -match '^\d+$') -or [int]$subnetSelection -le 0 -or [int]$subnetSelection -gt $subnets.Count) {
                        Write-Host "Invalid selection. Operation canceled." -ForegroundColor Red
                        return
                    }

                    $selectedSubnet = $subnets[[int]$subnetSelection - 1].Id
                    Update-AzKeyVaultNetworkRuleSet -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -VirtualNetworkResourceId @($selectedSubnet) -PassThru -ErrorAction Stop
                    Write-Host "Access granted to VNet '$($selectedVNet.Name)' with Subnet '$($subnets[[int]$subnetSelection - 1].Name)'." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to grant access to VNet. Error: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Operation canceled." -ForegroundColor Yellow
            }
        } elseif ($vnetAction -eq '2') {
            Write-Host
            Write-Host "Denying access to VNet '$($selectedVNet.Name)' for Key Vault '$keyVaultName'..." -ForegroundColor Blue
            Write-Host "Do you wish to proceed? (y/n): " -ForegroundColor Cyan -NoNewline
            $confirm = Read-Host
            if ($confirm -eq 'y') {
                try {
                    Update-AzKeyVaultNetworkRuleSet -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -VirtualNetworkResourceId @() -PassThru -ErrorAction Stop
                    Write-Host "Access denied to VNet '$($selectedVNet.Name)'." -ForegroundColor Green
                } catch {
                    Write-Host "Failed to deny access to VNet. Error: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "Operation canceled." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "Failed to manage VNet access. Error: $_" -ForegroundColor Red
    }
}

# Main Menu
do {
    Write-Host
    Write-Host "Available Azure Key Vault firewall actions..." -ForegroundColor Blue
    Write-Host "1. List firewall status"
    Write-Host "2. Enable / disable firewall"
    Write-Host "3. View VNet assignments"
    Write-Host "4. Manage VNet assignments"
    Write-Host "Enter the number of the action you wish to take: " -ForegroundColor Cyan -NoNewline
    $menuAction = Read-Host
    if (-not ($menuAction -eq '1' -or $menuAction -eq '2' -or $menuAction -eq '3' -or $menuAction -eq '4')) {
        Write-Host "Invalid option selected. Returning to main menu..." -ForegroundColor Red
        continue
    }

    if ($menuAction -eq '1') {
        List-FirewallStatus
    } elseif ($menuAction -eq '2' -or $menuAction -eq '3' -or $menuAction -eq '4') {
        $keyVaults = List-KeyVaults
        if (-not $keyVaults) {
            Write-Host "No Key Vaults available. Returning to main menu..." -ForegroundColor Red
            continue
        }

        Write-Host "Enter the number of the Key Vault you wish to manage: " -ForegroundColor Cyan -NoNewline
        $kvSelection = Read-Host
        if (-not ($kvSelection -match '^\d+$') -or [int]$kvSelection -le 0 -or [int]$kvSelection -gt $keyVaults.Count) {
            Write-Host "Invalid selection. Returning to main menu..." -ForegroundColor Red
            continue
        }
        $selectedKeyVault = $keyVaults[[int]$kvSelection - 1]

        if ($menuAction -eq '2') {
            Manage-Firewall -keyVaultName $selectedKeyVault.VaultName
        } elseif ($menuAction -eq '3') {
            View-VNetAssignments -keyVaultName $selectedKeyVault.VaultName
        } elseif ($menuAction -eq '4') {
            Manage-VNetAccess -keyVaultName $selectedKeyVault.VaultName
        }
    }

    Write-Host
    Write-Host "Would you like to perform another firewall or VNet management action? (y/n): " -ForegroundColor Cyan -NoNewline
    $continue = (Read-Host).ToLower()
} while ($continue -eq 'y')