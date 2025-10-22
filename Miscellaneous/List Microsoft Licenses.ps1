<#
.SYNOPSIS
    Retrieve and saves all Microsoft 365 subscribed license info

.DESCRIPTION
    Retrieves a full list of all Microsoft 365 subscribed licenses
    Loops through that list to retrieve detailed information on each one
    Saves the first list as Microsoft_License_List.txt
    Saves the first list as Microsoft_License_Detail.txt

.NOTES
    Created 2025.09.23 by Joe McLain (joe@bvu.edu)
    Updated on 2025.10.20 at 1613 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Retrieving and displaying a list of all Microsoft licenses..."
Write-Host

# ===============================================
# Variable declaration
# ===============================================
$filepath = (Get-Location).Path
$filename = 'Microsoft_License_List.txt'
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# ===============================================
# Module management
# ===============================================
Write-Host
Write-Host "Determining whether required modules are installed..." -ForegroundColor Cyan
$requiredModules = @('Microsoft.Graph.Identity.DirectoryManagement')
foreach ($module in $requiredModules) {
    Write-Host "  Checking module '$module'..." -ForegroundColor Blue
    if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "  Module '$module' not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "    Module '$module' installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "    Failed to install module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "    Module '$module' is already installed." -ForegroundColor Green
    }
    if (-not (Get-Module -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "  Module '$module' not currently imported. Importing..." -ForegroundColor Yellow
        try {
            Import-Module -Name $module -ErrorAction Stop
            Write-Host "  Module '$module' imported successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "    Failed to import module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "    Module '$module' is already imported." -ForegroundColor Green
    }
}

# ===============================================
# Authentication
# ===============================================
    Write-Host
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    $RequiredScopes = @('Directory.Read.All')
    Connect-MgGraph -Scopes $RequiredScopes -ErrorAction Stop | Out-Null
    Write-Host "  Connected to Microsoft Graph." -ForegroundColor Green

# ===============================================
# Subscription retrieval
# ===============================================
    Write-Host
    Write-Host "Retrieving subscribed SKUs via Get-MgSubscribedSku -All ..." -ForegroundColor Cyan
    $skus = Get-MgSubscribedSku -All

    Write-Host
    Write-Host "Writing full results (JSON) to file ..." -ForegroundColor Cyan
    if ($skus) {
        try {
            $fullPath = Join-Path -Path $filepath -ChildPath $filename
            $skus | ConvertTo-Json -Depth 10 | Set-Content -Path $fullPath -Encoding UTF8
            Write-Host "  $filename written to $filepath" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to write output file. Error: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  No subscribed SKUs were returned." -ForegroundColor Yellow
    }

# ===============================================
# Per-SKU license detail computation & export
# ===============================================
Write-Host
Write-Host "Building per-SKU license detail (assigned, available, plan breakdown)..." -ForegroundColor Cyan

# Guard: ensure we have data to process
if (-not $skus -or $skus.Count -eq 0) {
    Write-Host "  No SKUs in memory to analyze. Skipping detail export." -ForegroundColor Yellow
}
else {
    $licenseDetails = foreach ($sku in $skus) {
        # Normalize numeric inputs
        $enabled    = [int]($sku.PrepaidUnits.Enabled   ?? 0)
        $warning    = [int]($sku.PrepaidUnits.Warning   ?? 0)
        $suspended  = [int]($sku.PrepaidUnits.Suspended ?? 0)
        $lockedOut  = [int]($sku.PrepaidUnits.LockedOut ?? 0)
        $consumed   = [int]($sku.ConsumedUnits          ?? 0)

        # Derived metrics
        $availableEnabledOnly      = [math]::Max($enabled - $consumed, 0)
        $availableIncludingWarning = [math]::Max(($enabled + $warning) - $consumed, 0)
        $totalPrepaidAllStates     = $enabled + $warning + $suspended + $lockedOut
        $overAssignedBy            = $consumed - ($enabled + $warning)
        $isOverAssigned            = $overAssignedBy -ge 1

        $pctAssignedOfEnabled = if ($enabled -gt 0) {
            [math]::Round(($consumed / $enabled) * 100, 2)
        } else { $null }

        $pctAssignedOfEnabledPlusWarning = if (($enabled + $warning) -gt 0) {
            [math]::Round(($consumed / ($enabled + $warning)) * 100, 2)
        } else { $null }

        # Flatten service plans for readability
        $plans = @()
        if ($sku.ServicePlans) {
            $plans = $sku.ServicePlans | ForEach-Object {
                [pscustomobject]@{
                    ServicePlanName    = $_.ServicePlanName
                    ServicePlanId      = $_.ServicePlanId
                    AppliesTo          = $_.AppliesTo
                    ProvisioningStatus = $_.ProvisioningStatus
                }
            }
        }

        # Output detail record per SKU
        [pscustomobject]@{
            SkuPartNumber                      = $sku.SkuPartNumber
            SkuId                              = $sku.SkuId
            AppliesTo                          = $sku.AppliesTo
            CapabilityStatus                   = $sku.CapabilityStatus
            SubscriptionIds                    = $sku.SubscriptionIds

            ConsumedUnits                      = $consumed
            Prepaid_Enabled                    = $enabled
            Prepaid_Warning                    = $warning
            Prepaid_Suspended                  = $suspended
            Prepaid_LockedOut                  = $lockedOut
            TotalPrepaid_AllStates             = $totalPrepaidAllStates

            Available_EnabledOnly              = $availableEnabledOnly
            Available_IncludingWarning         = $availableIncludingWarning
            PercentAssigned_OfEnabled          = $pctAssignedOfEnabled
            PercentAssigned_OfEnabledPlusWarn  = $pctAssignedOfEnabledPlusWarning
            IsOverAssigned                     = $isOverAssigned
            OverAssignedBy                     = if ($isOverAssigned) { $overAssignedBy } else { 0 }

            ServicePlans                       = $plans
        }
    }

    Write-Host
    Write-Host "Writing per-SKU detail (JSON) to file ..." -ForegroundColor Cyan
    try {
        $detailFilename = 'Microsoft_License_Detail.txt'
        $detailFullPath = Join-Path -Path $filepath -ChildPath $detailFilename
        $licenseDetails | ConvertTo-Json -Depth 10 | Set-Content -Path $detailFullPath -Encoding UTF8
        Write-Host "  $detailFilename written to $filepath" -ForegroundColor Green
        Write-Host "  Processed $($licenseDetails.Count) SKUs." -ForegroundColor Blue
    }
    catch {
        Write-Host "  Failed to write detail output file. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}
