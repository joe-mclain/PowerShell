<#
.SYNOPSIS
    Creates a Purview Premium eDiscovery (Advanced) case, places custodians on indefinite hold (Exchange + OneDrive), and runs an initial content search using a shared KQL filter.

.DESCRIPTION
    This script:
      • Prompts for case metadata, custodial UPNs, and optional keywords.
      • Builds a single KQL query (participants + keywords) used for both hold scoping and search.
      • Applies an indefinite custodial hold to custodians’ mailboxes (email, calendar, contacts, tasks, Teams 1:1/group chats, archives/Recoverable Items) and personal OneDrive sites.
      • Creates and starts a Compliance Search inside the case with the same KQL.
      • Outputs a concise summary of held locations and search start status.

.NOTES
  - Created 2025.05.19 by Joe McLain (joe@bvu.edu)
  - Last modified 2025.09.30 at 1119 by Joe McLain (joe@bvu.edu)
#>

$ErrorActionPreference = 'Stop'   # abort on any unhandled error

Clear-Host
Write-Host
Write-Host "Create Purview eDiscovery case & search..."
Write-Host

#──────────────────────────────────────────────────────────────────────
# Module management
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Determining whether required modules are available..." -ForegroundColor Cyan
$requiredModules = @(
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Users',
    'ExchangeOnlineManagement'
)

foreach ($module in $requiredModules) {
    Write-Host "  Checking module '$module'..." -ForegroundColor Blue
    if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "    Module '$module' not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            Write-Host "      Module '$module' installed successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "      Failed to install module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "    Module '$module' is already installed." -ForegroundColor Green
    }
    if (-not (Get-Module -Name $module -ErrorAction SilentlyContinue)) {
        Write-Host "    Module '$module' not currently imported. Importing..." -ForegroundColor Yellow
        try {
            Import-Module -Name $module -ErrorAction Stop
            Write-Host "      Module '$module' imported successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "      Failed to import module '$module'. Error: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "    Module '$module' is already imported." -ForegroundColor Green
    }
}

#──────────────────────────────────────────────────────────────────────
# Connections
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Establishing service connections..." -ForegroundColor Cyan

# Exchange Online
Write-Host "  Requesting Exchange admin credential..." -ForegroundColor Blue
$cred = Get-Credential -Message 'Enter Exchange admin UPN'

Write-Host "  Connecting to Exchange Online..." -ForegroundColor Blue
try {
    Connect-ExchangeOnline -UserPrincipalName $cred.UserName -ShowBanner:$false -ErrorAction Stop
    Write-Host "    Exchange Online connected." -ForegroundColor Green
}
catch {
    Write-Host "    Exchange Online connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Purview Security & Compliance Center
Write-Host "  Connecting to Purview Security & Compliance Center..." -ForegroundColor Blue
try {
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "    Purview (SCC) session established." -ForegroundColor Green
}
catch {
    Write-Host "    Purview (SCC) connection failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
#──────────────────────────────────────────────────────────────────────
# Case metadata
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Gathering case metadata..." -ForegroundColor Cyan
do {
    Write-Host "  Enter eDiscovery case name: " -ForegroundColor Cyan -NoNewLine
    $caseName = Read-Host
} until ($caseName)

do {
    Write-Host "  Enter case description: " -ForegroundColor Cyan -NoNewLine
    $caseDescription = Read-Host
} until ($caseDescription)

#──────────────────────────────────────────────────────────────────────
# Custodians
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Collecting custodians..." -ForegroundColor Cyan
$mailboxTargets = @()   # addresses for the hold
$displayNames   = @()   # friendly names for summary
Write-Host "  Custodians are people whose data you need to preserve and search." -ForegroundColor Cyan
Write-Host "  Enter custodial UPNs, one per line (blank line ends):" -ForegroundColor Cyan

while ($true) {
    Write-Host "  UPN: " -ForegroundColor Cyan -NoNewLine
    $upn = Read-Host
    if (-not $upn) { break }

    try {
        Write-Host "    Validating '$upn' via Exchange Online..." -ForegroundColor Blue
        $recipient = Get-EXORecipient -Identity $upn -ErrorAction Stop

        # Prefer PrimarySmtpAddress for Exchange & Purview targeting
        $address = if ($recipient.PrimarySmtpAddress) { $recipient.PrimarySmtpAddress.ToString() } else { $upn }

        $mailboxTargets += $address
        $displayNames   += $recipient.DisplayName
        Write-Host "    $($recipient.DisplayName) validated as $address." -ForegroundColor Green
    }
    catch {
        Write-Host "    User '$upn' not found. Please enter a valid UPN." -ForegroundColor Red
    }
}

if (-not $mailboxTargets) {
    Write-Host "  No custodians entered." -ForegroundColor Red
    exit 1
}

#──────────────────────────────────────────────────────────────────────
# Optional keywords
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Collecting optional keywords..." -ForegroundColor Cyan
$keywords = @()
Write-Host "  Keywords / phrases (blank line ends):" -ForegroundColor Cyan
while ($true) {
    Write-Host "  Keyword or phrase: " -ForegroundColor Cyan -NoNewLine
    $kw = Read-Host
    if (-not $kw) { break }
    $keywords += $kw
    Write-Host "    Added keyword: $kw" -ForegroundColor Blue
}

#──────────────────────────────────────────────────────────────────────
# Build KQL
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Building KQL query..." -ForegroundColor Cyan

$participant   = ($mailboxTargets | ForEach-Object { "Participants:`"$_`"" }) -join ' OR '
$keywordClause = if ($keywords.Count) {
    $escaped = $keywords | ForEach-Object { "`"" + ($_ -replace '"','\"') + "`"" }
    "Keywords (" + ($escaped -join ' OR ') + ")"
}
$kqlParts = @($participant, $keywordClause) | Where-Object { $_ }
$kql      = $kqlParts -join ' OR '

Write-Host "  Constructed KQL query:" -ForegroundColor Blue
Write-Host "    $kql" -ForegroundColor Yellow

#──────────────────────────────────────────────────────────────────────
# Create eDiscovery case
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Creating eDiscovery case..." -ForegroundColor Cyan
try {
    Write-Host "  Submitting New-ComplianceCase..." -ForegroundColor Blue
    $case   = New-ComplianceCase -Name $caseName -CaseType AdvancedEdiscovery `
              -Description $caseDescription -ErrorAction Stop
    $caseId = $case.Identity
    Write-Host "  Case created. Identity: $caseId" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR creating case: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#──────────────────────────────────────────────────────────────────────
# Build location arrays
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Building location arrays..." -ForegroundColor Cyan

$tenantName     = 'buenavistauniversity'
$exchangeList   = $mailboxTargets
$sharePointList = @()

foreach ($upn in $mailboxTargets) {
    if (-not ($upn -and $upn.Contains('@'))) {
        Write-Host "  Skipped invalid UPN: '$upn'" -ForegroundColor Yellow
        continue
    }

    $alias, $dom = $upn.Split('@', 2)
    $cleanDom    = $dom -replace '\.', '_'
    $siteUrl     = "https://$tenantName-my.sharepoint.com/personal/${alias}_$cleanDom"
    $sharePointList += $siteUrl
    Write-Host "  Added OneDrive site: $siteUrl" -ForegroundColor Green
}

if (-not $sharePointList) {
    Write-Host "  No valid OneDrive sites built. Please verify your custodial UPNs." -ForegroundColor Red
    exit 1
}

#──────────────────────────────────────────────────────────────────────
# Hold policy & rule
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Creating hold policy..." -ForegroundColor Cyan
$policyName = "$caseName hold policy"
$ruleName   = "$caseName rule"
try {
    Write-Host "  Submitting New-CaseHoldPolicy..." -ForegroundColor Blue
    $policy = New-CaseHoldPolicy `
        -Case               $caseId `
        -Name               $policyName `
        -ExchangeLocation   $exchangeList `
        -SharePointLocation $sharePointList `
        -ErrorAction        Stop
    Write-Host "  Hold policy created: $($policy.Identity)" -ForegroundColor Green
}
catch {
    Write-Host "  ERROR creating hold policy: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host
Write-Host "Creating hold rule..." -ForegroundColor Cyan
try {
    Write-Host "  Submitting New-CaseHoldRule..." -ForegroundColor Blue
    New-CaseHoldRule `
        -Policy            $policy.Identity `
        -Name              $ruleName `
        -ContentMatchQuery $kql `
        -ErrorAction       Stop
    Write-Host "  Hold rule created." -ForegroundColor Green
}
catch {
    Write-Host "  ERROR creating rule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#──────────────────────────────────────────────────────────────────────
# Initial Compliance Search (runs once now, inside the case)
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Create initial search..." -ForegroundColor Cyan
$searchName = "$caseName content search"
try {
    Write-Host "  Submitting New-ComplianceSearch..." -ForegroundColor Blue
    New-ComplianceSearch `
        -Name               $searchName `
        -Case               $caseId `
        -ExchangeLocation   $exchangeList `
        -SharePointLocation $sharePointList `
        -ContentMatchQuery  $kql `
        -ErrorAction        Stop
    Write-Host "  Starting compliance search..." -ForegroundColor Blue
    Start-ComplianceSearch -Identity $searchName -ErrorAction Stop
    Write-Host "  Compliance search started." -ForegroundColor Green
}
catch {
    Write-Host "  ERROR creating / starting search: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#──────────────────────────────────────────────────────────────────────
# Summary
#──────────────────────────────────────────────────────────────────────
Write-Host
Write-Host "Summarizing hold and search setup..." -ForegroundColor Cyan
Write-Host "  ===============  HOLD SUMMARY  ===============" -ForegroundColor Green
Write-Host "  Custodian mailboxes:" -ForegroundColor Cyan
$displayNames | ForEach-Object { Write-Host "    • $_" }
Write-Host "    - Includes email, calendar, contacts, tasks, Teams 1:1 chats, archives." -ForegroundColor DarkGray

Write-Host
Write-Host "  Custodian OneDrive sites:" -ForegroundColor Cyan
$sharePointList | ForEach-Object { Write-Host "    • $_" }
Write-Host "    - All files, versions, metadata." -ForegroundColor DarkGray

Write-Host
Write-Host "  Compliance Search '$searchName' started and linked to the case." -ForegroundColor Cyan
Write-Host "  ==============================================" -ForegroundColor Yellow
Write-Host
Write-Host "Hold and search setup complete." -ForegroundColor Green