<#
.SYNOPSIS
Audits access to an Azure Key Vault using its associated Log Analytics workspace.

.DESCRIPTION
- Retrieves the associated Log Analytics workspace for the specified Key Vault.
- Queries and displays audit logs (time, caller, identity, operation name).
- Provides detailed debug information for query execution.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.15 at 1118 by Joe McLain (joe@bvu.edu)
#>

param (
    [switch]$isAuthenticated
)

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Magenta
    exit
}

Write-Host
Write-Host "Audit Azure Key Vault Access..." -ForegroundColor Blue
Write-Host

# Ensure requisite PowerShell modules are installed and imported.
Write-Host "Checking for the required PowerShell modules..." -ForegroundColor DarkCyan
$requiredModules = @('Az.KeyVault', 'Az.Monitor', 'Az.OperationalInsights')
foreach ($module in $requiredModules) {
    try {
        if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
            Write-Host "Module '$module' not found. Installing..." -ForegroundColor Yellow
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        } else {
            Write-Host "Module '$module' is already installed." -ForegroundColor Green
        }

        if (-not (Get-Module -ListAvailable -Name $module | Where-Object { $_.Name -eq $module })) {
            Write-Host "Importing module '$module'..." -ForegroundColor Yellow
            Import-Module -Name $module -ErrorAction Stop
            Write-Host "Module '$module' imported successfully." -ForegroundColor Green
        } else {
            Write-Host "Module '$module' is already imported." -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to install or import module '$module'. Error: $_" -ForegroundColor Red
        exit
    }
}

# Authenticate to Azure if not already authenticated
if (-not $isAuthenticated) {
    Write-Host "Authenticating to Azure..." -ForegroundColor DarkCyan
    try {
        Connect-AzAccount -ErrorAction Stop
        Write-Host "Authentication successful." -ForegroundColor Green
    } catch {
        Write-Host "Authentication failed. Error: $_" -ForegroundColor Red
        exit
    }
}

# Function to list and select a Key Vault
function Select-KeyVault {
    try {
        $keyVaults = Get-AzKeyVault -ErrorAction Stop
    } catch {
        Write-Host "Failed to retrieve Key Vaults. Error: $_" -ForegroundColor Red
        exit
    }

    if (-not $keyVaults) {
        Write-Host "No Azure Key Vaults found in the subscription." -ForegroundColor Red
        exit
    }

    Write-Host
    Write-Host "Available Key Vaults:" -ForegroundColor DarkCyan
    for ($i = 0; $i -lt $keyVaults.Count; $i++) {
        Write-Host "$($i + 1). $($keyVaults[$i].VaultName) in Resource Group: $($keyVaults[$i].ResourceGroupName)"
    }

    $selection = $null
    while (-not $selection) {
        Write-Host "Enter the number of the Key Vault to audit: " -ForegroundColor Cyan -NoNewline
        $input = Read-Host
        if ($input -match '^\d+$' -and [int]$input -gt 0 -and [int]$input -le $keyVaults.Count) {
            $selection = $keyVaults[[int]$input - 1]
        } else {
            Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        }
    }

    return $selection
}

# Function to find associated Log Analytics workspace for the Key Vault
function Get-LogAnalyticsWorkspace {
    param (
        [string]$keyVaultName,
        [string]$resourceGroupName
    )

    try {
        Write-Host
        Write-Host "Retrieving diagnostic settings for Key Vault '$keyVaultName'..." -ForegroundColor Cyan
        $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId (Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName).ResourceId

        if ($diagnosticSettings -and $diagnosticSettings.WorkspaceId) {
            Write-Host "Found associated Log Analytics workspace: $($diagnosticSettings.WorkspaceId)" -ForegroundColor Green
            return $diagnosticSettings.WorkspaceId
        } else {
            Write-Host "No associated Log Analytics workspace found for Key Vault '$keyVaultName'." -ForegroundColor Red
            return $null
        }
    } catch {
        Write-Host "Failed to retrieve diagnostic settings. Error: $_" -ForegroundColor Red
        return $null
    }
}

# Function to retrieve and display audit logs for a Key Vault
function Audit-KeyVaultAccess {
    param (
        [string]$keyVaultName,
        [string]$workspaceId
    )

    try {
        Write-Host
        Write-Host "Retrieving audit logs for Key Vault '$keyVaultName'..." -ForegroundColor Cyan

        # Define the KQL query to retrieve access logs
        $query = @"
        AzureDiagnostics
        | where ResourceType == 'VAULT' and OperationName == 'SecretGet'
        | where VaultName_s == '$keyVaultName'
        | project TimeGenerated, Caller, Identity, OperationName
        | order by TimeGenerated desc
"@

        # Execute the query in Log Analytics
        Write-Host "DEBUG: Executing Log Analytics query with Invoke-AzOperationalInsightsQuery..." -ForegroundColor Magenta
        Write-Host "DEBUG: Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $query" -ForegroundColor Magenta
        $logs = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspaceId -Query $query

        # Check for errors or invalid status codes
        if (-not $logs -or $logs.HttpStatusCode -ne 200) {
            Write-Host "Error: Query returned an invalid status code or no results were found. Status Code: $($logs.HttpStatusCode)" -ForegroundColor Red
            Write-Host "Please ensure the workspace is correctly configured and contains relevant log data." -ForegroundColor Red
            return
        }

        # Display the access logs if available
        if ($logs.Results.Count -gt 0) {
            Write-Host "Access log for '$keyVaultName':" -ForegroundColor Yellow
            $logs.Results | Format-Table TimeGenerated, Caller, Identity, OperationName -AutoSize
        } else {
            Write-Host "No access logs found for Key Vault '$keyVaultName'." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to retrieve audit logs. Error: $_" -ForegroundColor Red
    }
}

# Main script operation loop
do {
    # Prompt for Key Vault selection
    $selectedKeyVault = Select-KeyVault
    $keyVaultName = $selectedKeyVault.VaultName
    $resourceGroupName = $selectedKeyVault.ResourceGroupName

    # Get the associated Log Analytics workspace
    $workspaceId = Get-LogAnalyticsWorkspace -keyVaultName $keyVaultName -resourceGroupName $resourceGroupName
    if (-not $workspaceId) {
        Write-Host "Unable to proceed without an associated Log Analytics workspace." -ForegroundColor Red
        continue
    }

    # Call the audit function
    Audit-KeyVaultAccess -keyVaultName $keyVaultName -workspaceId $workspaceId

    # Ask if the user wants to audit another Key Vault with input validation
    do {
        Write-Host
        Write-Host "Would you like to audit another Key Vault? (y/n): " -ForegroundColor Cyan -NoNewline
        $continue = (Read-Host).ToLower()
    } while ($continue -notmatch '^(y|n)$')

} while ($continue -eq 'y')
