<#
.SYNOPSIS
Configures Azure Key Vault diagnostic settings to send logs and metrics to a selected Log Analytics Workspace.

.DESCRIPTION
- Lists available Key Vaults and prompts for selection.
- Lists resource groups and prompts for a Log Analytics Workspace resource group.
- Prompts for a Log Analytics Workspace within the chosen resource group.
- Applies diagnostic settings (logs and metrics) to the selected Key Vault.
- Validates that diagnostic settings were successfully applied.
- Offers to repeat the process for additional Key Vaults.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.12 at 0929 by Joe McLain (joe@bvu.edu)
#>

param (
    [switch]$isAuthenticated
)

Clear-Host
Write-Host "Configuring Azure Key Vault Analytics Reporting..." -ForegroundColor Blue
Write-Host

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Cyan
    exit
}

# Install and import required PowerShell modules
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Az.KeyVault', 'Az.Monitor', 'Az.OperationalInsights')
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

    # Import the module
    try {
        Import-Module -Name $module -ErrorAction Stop
        Write-Host "Module '$module' imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to import module '$module'. Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Authenticate to Azure if not already authenticated
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure..." -ForegroundColor Cyan
    Connect-AzAccount -ErrorAction Stop
}

# Function to retrieve and list Key Vaults
function List-KeyVaults {
    Write-Host
    Write-Host "Retrieving list of Azure Key Vaults..." -ForegroundColor Blue
    $keyVaults = Get-AzKeyVault
    
    # Check if any Key Vaults were found
    if (-not $keyVaults) {
        Write-Host "No Key Vaults found." -ForegroundColor Red
        exit
    }

    # Display Key Vaults with a numbered list
    for ($i = 0; $i -lt $keyVaults.Count; $i++) {
        Write-Host "$($i + 1). $($keyVaults[$i].VaultName) in Resource Group: $($keyVaults[$i].ResourceGroupName)"
    }

    return $keyVaults
}

# Function to validate Key Vault selection
function Validate-KeyVaultSelection {
    param(
        [int]$keyVaultsCount,
        [string]$selection
    )
    if ($selection -match '^\d+$' -and [int]$selection -gt 0 -and [int]$selection -le $keyVaultsCount) {
        return $true
    } else {
        return $false
    }
}

# Function to retrieve and display list of workspaces, and select one
function Select-LogAnalyticsWorkspace {
    param (
        [string]$resourceGroupName
    )

    Write-Host
    Write-Host "Retrieving list of Log Analytics Workspaces in Resource Group '$resourceGroupName'..." -ForegroundColor Cyan

    # Get list of workspaces
    $workspaces = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName
    if (-not $workspaces) {
        Write-Host "No Log Analytics Workspaces found in resource group '$resourceGroupName'." -ForegroundColor Red
        return $null
    }

    # Display workspaces
    for ($i = 0; $i -lt $workspaces.Count; $i++) {
        Write-Host "$($i + 1). $($workspaces[$i].Name)"
    }

    $selectedWorkspace = $null
    $validInput = $false
    while (-not $validInput) {
        Write-Host
        Write-Host "Please select a Log Analytics Workspace by number: " -ForegroundColor Cyan -NoNewline
        $workspaceSelection = Read-Host
        if ($workspaceSelection -match '^\d+$' -and [int]$workspaceSelection -gt 0 -and [int]$workspaceSelection -le $workspaces.Count) {
            $selectedWorkspace = $workspaces[[int]$workspaceSelection - 1].Name
            Write-Host "Selected Workspace: $selectedWorkspace" -ForegroundColor Green
            $validInput = $true
        } else {
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
        }
    }

    return $selectedWorkspace
}

# Function to configure secret expiry alerts
function Configure-SecretExpiryAlert {
    param (
        [string]$keyVaultName,
        [string]$keyVaultRG,
        [string]$workspaceName,
        [string]$workspaceRG
    )

    try {
        # Retrieve the subscription ID from the context
        $subscriptionId = (Get-AzContext).Subscription.Id
        Write-Host "DEBUG: SubscriptionId = $subscriptionId"

        # Get the fully qualified workspace ID
        $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $workspaceRG -Name $workspaceName
        if (-not $workspace) {
            Write-Host "Error: Log Analytics Workspace not found." -ForegroundColor Red
            return
        }

        $workspaceId = $workspace.ResourceId
        Write-Host "DEBUG: WorkspaceId = $workspaceId"

        # Ensure the workspace ID has the full path structure
        if ($workspaceId -notmatch "^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.OperationalInsights/workspaces/.+") {
            Write-Host "Error: The WorkspaceId does not have the expected format." -ForegroundColor Red
            return
        }

        # Enable diagnostic settings with AuditEvent category group
        Write-Host "Setting up diagnostic settings for Key Vault '$keyVaultName' in resource group '$keyVaultRG'..." -ForegroundColor Green
        Write-Host "DEBUG: New-AzDiagnosticSetting -Name 'Azure Key Vault Alerting to Log Analytics Workspace' -ResourceId '/subscriptions/$subscriptionId/resourceGroups/$keyVaultRG/providers/Microsoft.KeyVault/vaults/$keyVaultName' -WorkspaceId $workspaceId -Log @(New-AzDiagnosticSettingLogSettingsObject -Category 'AuditEvent' -Enabled $true) -Metric @(New-AzDiagnosticSettingMetricSettingsObject -Category 'AllMetrics' -Enabled $true)"

        New-AzDiagnosticSetting -Name "Azure Key Vault Alerting to Log Analytics Workspace" `
            -ResourceId "/subscriptions/$subscriptionId/resourceGroups/$keyVaultRG/providers/Microsoft.KeyVault/vaults/$keyVaultName" `
            -WorkspaceId $workspaceId `
            -Log @(
                New-AzDiagnosticSettingLogSettingsObject -Category "AuditEvent" -Enabled $true
            ) `
            -Metric @(
                New-AzDiagnosticSettingMetricSettingsObject -Category "AllMetrics" -Enabled $true
            ) -ErrorAction Stop

        Write-Host "Diagnostic settings applied. Waiting 45 seconds for propagation..." -ForegroundColor Yellow
        Start-Sleep -Seconds 45

        # Validation step
        Write-Host "Validating diagnostic settings for Key Vault '$keyVaultName'..." -ForegroundColor Yellow
        $diagSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$subscriptionId/resourceGroups/$keyVaultRG/providers/Microsoft.KeyVault/vaults/$keyVaultName"
        if ($diagSettings) {
            Write-Host "Diagnostic settings successfully applied for Key Vault '$keyVaultName'." -ForegroundColor Green
        } else {
            Write-Host "Failed to apply diagnostic settings for Key Vault '$keyVaultName'." -ForegroundColor Red
        }

    } catch {
        Write-Host "Error encountered: $_" -ForegroundColor Red
    }
}

# Main do-while loop to allow for multiple Key Vault configurations
do {
    # List Key Vaults for selection
    $keyVaults = List-KeyVaults

    # Prompt user to select a Key Vault
    $selectedVault = $null
    $selectedVaultRG = $null
    $validInput = $false
    while (-not $validInput) {
        Write-Host
        Write-Host "Please select a Key Vault by number: " -ForegroundColor Cyan -NoNewline
        $selectionIndex = Read-Host
        if (Validate-KeyVaultSelection -keyVaultsCount $keyVaults.Count -selection $selectionIndex) {
            $selectedVault = $keyVaults[[int]$selectionIndex - 1].VaultName
            $selectedVaultRG = $keyVaults[[int]$selectionIndex - 1].ResourceGroupName
            Write-Host "Selected Key Vault: $selectedVault in Resource Group: $selectedVaultRG" -ForegroundColor Green
            $validInput = $true
        } else {
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        }
    }

    # List resource groups and select one for the Log Analytics Workspace
    $resourceGroups = Get-AzResourceGroup
    if (-not $resourceGroups) {
        Write-Host "No resource groups found." -ForegroundColor Red
        exit
    }

    # Display resource groups with a numbered list for Log Analytics Workspace selection
    for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
        Write-Host "$($i + 1). $($resourceGroups[$i].ResourceGroupName)"
    }

    $selectedRGForWorkspace = $null
    $validInput = $false
    while (-not $validInput) {
        Write-Host
        Write-Host "Please select a Resource Group for the Log Analytics Workspace by number: " -ForegroundColor Cyan -NoNewline
        $rgSelection = Read-Host
        if ($rgSelection -match '^\d+$' -and [int]$rgSelection -gt 0 -and [int]$rgSelection -le $resourceGroups.Count) {
            $selectedRGForWorkspace = $resourceGroups[[int]$rgSelection - 1].ResourceGroupName
            Write-Host "Selected Resource Group for Workspace: $selectedRGForWorkspace" -ForegroundColor Green
            $validInput = $true
        } else {
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        }
    }

    # Get list of workspaces and select one
    $selectedWorkspace = Select-LogAnalyticsWorkspace -resourceGroupName $selectedRGForWorkspace

    # Summary and confirmation before action
    Write-Host
    Write-Host "Summary of actions to be performed:" -ForegroundColor Yellow
    Write-Host "1. Key Vault: $selectedVault in Resource Group: $selectedVaultRG" -ForegroundColor Blue
    Write-Host "2. Log Analytics Workspace: $selectedWorkspace in Resource Group: $selectedRGForWorkspace" -ForegroundColor Blue
    Write-Host "`nDo you confirm these actions? (y/n): " -ForegroundColor Cyan -NoNewline
    $confirmation = Read-Host

    if ($confirmation.ToLower() -eq 'y') {
        Write-Host "`nProceeding with the configuration..." -ForegroundColor Green
        Configure-SecretExpiryAlert -keyVaultName $selectedVault -keyVaultRG $selectedVaultRG -workspaceName $selectedWorkspace -workspaceRG $selectedRGForWorkspace
    } else {
        Write-Host "`nOperation cancelled by user." -ForegroundColor Red
    }

    # Ask if the user wants to configure alerting for another Azure Key Vault
    Write-Host
    Write-Host "Would you like to configure alerting for another Azure Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
    $configureAnother = Read-Host

} while ($configureAnother.ToLower() -eq 'y')