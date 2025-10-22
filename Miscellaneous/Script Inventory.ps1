<#
.SYNOPSIS
    Inventory PowerShell scripts under the current folder, extracting SYNOPSIS, DESCRIPTION, and NOTES metadata.

.DESCRIPTION
    Starting at the folder from which it is run, this script recurses downward to find all *.ps1 files.
    For each file, it inspects the comment-based help blocks and, when present, extracts:
      - .SYNOPSIS (multi-line, until the next dotted section)
      - .DESCRIPTION (multi-line, until the next dotted section)
      - .NOTES lines for:
          Created YYYY.MM.DD by Name (email)
          Updated/Last updated [on] YYYY.MM.DD [at HHMM|HH:MM] by Name (email)
    It writes one XLSX in the working directory with two worksheets:
      - Inventory (columns: File Path, File Name, Synopsis, Description, Creation Date, Creator Name, Modification Date, Modification Time, Modifier Name)
      - Needing Updates (columns: File Path, File Name)
    “Needing updates” are files missing either .SYNOPSIS or .DESCRIPTION.

.NOTES
    Created 2025.09.23 by Joe McLain (joe@bvu.edu)
    Updated on 2025.09.24 at 0904 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Building inventory of PowerShell scripts from the current folder downward..." -ForegroundColor Cyan
Write-Host

# ===============================================
# Variable declaration
# ===============================================
$root             = (Get-Location).Path
$outXlsxName      = 'PowerShell_Scripts.xlsx'
$outXlsxPath      = Join-Path -Path $root -ChildPath $outXlsxName

# Containers for results
$goodRows   = New-Object System.Collections.Generic.List[object]
$needsRows  = New-Object System.Collections.Generic.List[object]

# ===============================================
# Regex helpers
# ===============================================
# Capture a full help block; require closing '#>' to begin a line to avoid inline '#>' examples
$reBlock = [regex]::new(
    '^\s*<\#\s*(?<content>[\s\S]*?)^\s*\#>',
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)

# Created line variants
$reCreated = [regex]::new('(?im)^\s*(?:This script was\s+)?created(?:\s+on)?\s+(?<date>\d{4}\.\d{2}\.\d{2})\s+by\s+(?<name>[^\r\n(]+)')
# Updated line variants
$reUpdated = [regex]::new('(?im)^\s*(?:This script was\s+)?(?:last\s+)?updated(?:\s+on)?\s+(?<date>\d{4}\.\d{2}\.\d{2})(?:\s+at\s+(?<time>\d{2}:?\d{2}))?\s+by\s+(?<name>[^\r\n(]+)')

# ===============================================
# Module management
# ===============================================
Write-Host
Write-Host "Determining whether required modules are installed..." -ForegroundColor Cyan
$requiredModules = @('ImportExcel')
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
# Normalize indentation
# ===============================================
function Normalize-Section {
    param([string]$text)
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }

    # Split into lines without altering internal spacing
    $lines = $text -split '\r?\n', 0

    # Remove leading/trailing completely blank lines only
    while ($lines.Count -gt 0 -and $lines[0] -match '^\s*$') { $lines = $lines[1..($lines.Count-1)] }
    while ($lines.Count -gt 0 -and $lines[-1] -match '^\s*$') { $lines = $lines[0..($lines.Count-2)] }
    if ($lines.Count -eq 0) { return "" }

    # Compute common indent across non-blank lines
    $indentLengths = foreach ($ln in $lines) {
        if ($ln -match '^\s*\S') {
            ($ln.Length - ($ln.TrimStart().Length))
        }
    }
    $commonIndent = ($indentLengths | Measure-Object -Minimum).Minimum
    if (-not $commonIndent) { $commonIndent = 0 }

    # Remove exactly the common indent from non-blank lines; keep blank lines untouched
    $normalized = foreach ($ln in $lines) {
        if ($ln -match '^\s*$') { $ln }
        else {
            $cut = [Math]::Min($commonIndent, $ln.Length)
            $ln.Substring($cut)
        }
    }

    # Join with original semantic line breaks
    return ($normalized -join [Environment]::NewLine)
}

# ===============================================
# Section extractor
# ===============================================
function Get-HelpSection {
    param(
        [Parameter(Mandatory)] [string] $Block,
        [Parameter(Mandatory)] [ValidateSet('SYNOPSIS','DESCRIPTION')] [string] $Section
    )

    $lines = $Block -split '\r?\n', 0

    $startIdx = -1
    $inlineRemainder = ''

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*\.$Section\b(.*)$") {
            $startIdx = $i
            $inlineRemainder = ($matches[1]).Trim()   # any text on same header line
            break
        }
    }
    if ($startIdx -lt 0) {
        return [PSCustomObject]@{ Text = ''; Next = $null }
    }

    # find next dotted section after start
    $endIdx = $lines.Count
    $nextHeaderName = $null
    for ($j = $startIdx + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^\s*\.[A-Za-z][A-Za-z0-9]*\b') {
            $endIdx = $j
            $nextHeaderName = ($lines[$j] -replace '^\s*\.', '') -replace '\s+.*$', ''
            break
        }
    }

    $bodyLines = @()
    if ($inlineRemainder.Length -gt 0) { $bodyLines += $inlineRemainder }
    if ($startIdx + 1 -le $endIdx - 1) {
        $bodyLines += $lines[($startIdx + 1)..($endIdx - 1)]
    }

    return [PSCustomObject]@{
        Text = ($bodyLines -join [Environment]::NewLine)
        Next = $nextHeaderName
    }
}

# ===============================================
# Discovery
# ===============================================
Write-Host
Write-Host "Scanning for *.ps1 files under: $root" -ForegroundColor Cyan
$files = Get-ChildItem -Path $root -Recurse -Filter *.ps1 -File | Sort-Object FullName
Write-Host "  Found $($files.Count) script file(s)." -ForegroundColor Yellow

# ===============================================
# Inspection
# ===============================================
Write-Host
Write-Host "Inspecting each file for valid header content..." -ForegroundColor Cyan
foreach ($file in $files) {
    $relativePath = [System.IO.Path]::GetRelativePath($root, $file.DirectoryName)
    if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = '.' }

    Write-Host "  Inspecting: $relativePath\$($file.Name)" -ForegroundColor Green

    # Robust file read (avoid null content)
    $content = $null
    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
    } catch {
        $needsRows.Add([PSCustomObject]@{ 'File Path' = $relativePath; 'File Name' = $file.Name })
        continue
    }
    if ([string]::IsNullOrWhiteSpace($content)) {
        $needsRows.Add([PSCustomObject]@{ 'File Path' = $relativePath; 'File Name' = $file.Name })
        continue
    }

    # Search all block comments for our sections
    $blocks = $reBlock.Matches($content)
    if (-not $blocks -or $blocks.Count -eq 0) {
        $needsRows.Add([PSCustomObject]@{ 'File Path' = $relativePath; 'File Name' = $file.Name })
        continue
    }

    $synopsisText = ""
    $descText     = ""
    $createdDate  = ""
    $creatorName  = ""
    $updatedDate  = ""
    $updatedTime  = ""
    $updatedName  = ""

    foreach ($m in $blocks) {
        $block = $m.Groups['content'].Value
        if ([string]::IsNullOrWhiteSpace($block)) { continue }

        if ([string]::IsNullOrWhiteSpace($synopsisText)) {
            $syn = Get-HelpSection -Block $block -Section 'SYNOPSIS'
            if ($syn -and $syn.Text) { $synopsisText = Normalize-Section $syn.Text }
        }

        if ([string]::IsNullOrWhiteSpace($descText)) {
            $des = Get-HelpSection -Block $block -Section 'DESCRIPTION'
            if ($des -and $des.Text) {
                $descText = Normalize-Section $des.Text
            }
        }

        if ([string]::IsNullOrWhiteSpace($createdDate) -or [string]::IsNullOrWhiteSpace($creatorName)) {
            $mc = $reCreated.Match($block)
            if ($mc.Success) {
                $createdDate = $mc.Groups['date'].Value
                $creatorName = $mc.Groups['name'].Value.Trim()
            }
        }

        if ([string]::IsNullOrWhiteSpace($updatedDate) -or [string]::IsNullOrWhiteSpace($updatedName)) {
            $mu = $reUpdated.Match($block)
            if ($mu.Success) {
                $updatedDate = $mu.Groups['date'].Value
                $updatedTime = ($mu.Groups['time'].Value ?? "").Trim()
                $updatedName = $mu.Groups['name'].Value.Trim()
            }
        }
    }

    $hasSynopsis    = -not [string]::IsNullOrWhiteSpace($synopsisText)
    $hasDescription = -not [string]::IsNullOrWhiteSpace($descText)

    if ($hasSynopsis -and $hasDescription) {
        # Use an [ordered] hashtable to preserve column order
        $goodRows.Add([PSCustomObject]([ordered]@{
            'File Path'         = $relativePath
            'File Name'         = $file.Name
            'Synopsis'          = $synopsisText
            'Description'       = $descText
            'Creation Date'     = $createdDate
            'Creator Name'      = $creatorName
            'Modification Date' = $updatedDate
            'Modification Time' = $updatedTime
            'Modifier Name'     = $updatedName
        }))
    } else {
        $needsRows.Add([PSCustomObject]([ordered]@{
            'File Path' = $relativePath
            'File Name' = $file.Name
        }))
    }
}

# ===============================================
# Output# ===============================================
Write-Host
Write-Host "Preparing Excel output..." -ForegroundColor Blue

# Remove existing workbook to avoid stale sheets
if (Test-Path -LiteralPath $outXlsxPath) {
    try {
        Remove-Item -LiteralPath $outXlsxPath -Force -ErrorAction Stop
    } catch {
        Write-Host "  Failed to remove existing $outXlsxName. Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Write Inventory sheet and set wrap
if ($goodRows.Count -gt 0) {
    $goodOrdered = $goodRows | Sort-Object 'File Path','File Name' | Select-Object `
        'File Path','File Name','Synopsis','Description','Creation Date','Creator Name','Modification Date','Modification Time','Modifier Name'

    $pkg = $goodOrdered | Export-Excel -Path $outXlsxPath -WorksheetName 'Inventory' -AutoSize -FreezeTopRow -BoldTopRow -AutoFilter -PassThru

    $ws = $pkg.Workbook.Worksheets['Inventory']
    $ws.Column(3).Style.WrapText = $true  # Synopsis
    $ws.Column(4).Style.WrapText = $true  # Description

    Close-ExcelPackage $pkg
    Write-Host "  Wrote 'Inventory' worksheet." -ForegroundColor Green
} else {
    $empty = [PSCustomObject]@{
        'File Path'=''; 'File Name'=''; 'Synopsis'=''; 'Description'=''; 'Creation Date'=''; 'Creator Name'=''; 'Modification Date'=''; 'Modification Time'=''; 'Modifier Name'=''
    }
    $pkg = $empty | Select-Object 'File Path','File Name','Synopsis','Description','Creation Date','Creator Name','Modification Date','Modification Time','Modifier Name' `
          | Export-Excel -Path $outXlsxPath -WorksheetName 'Inventory' -AutoSize -FreezeTopRow -BoldTopRow -AutoFilter -PassThru
    $ws = $pkg.Workbook.Worksheets['Inventory']
    $ws.Column(3).Style.WrapText = $true
    $ws.Column(4).Style.WrapText = $true
    Close-ExcelPackage $pkg
    Write-Host "  Created empty 'Inventory' worksheet." -ForegroundColor Yellow
}

# Append Needing Updates sheet
if ($needsRows.Count -gt 0) {
    $needsOrdered = $needsRows | Sort-Object 'File Path','File Name' | Select-Object 'File Path','File Name'
    $pkg2 = $needsOrdered | Export-Excel -Path $outXlsxPath -WorksheetName 'Needing Updates' -AutoSize -FreezeTopRow -BoldTopRow -AutoFilter -PassThru
    Close-ExcelPackage $pkg2
    Write-Host "  Wrote 'Needing Updates' worksheet." -ForegroundColor Green
} else {
    $emptyNeeds = [PSCustomObject]@{ 'File Path'=''; 'File Name'='' }
    $pkg3 = $emptyNeeds | Select-Object 'File Path','File Name' `
               | Export-Excel -Path $outXlsxPath -WorksheetName 'Needing Updates' -AutoSize -FreezeTopRow -BoldTopRow -AutoFilter -PassThru
    Close-ExcelPackage $pkg3
    Write-Host "  Created empty 'Needing Updates' worksheet." -ForegroundColor Yellow
}

Write-Host
Write-Host
Write-Host "  $root" -ForegroundColor Green -NoNewline
Write-Host "`\" -ForegroundColor Yellow -NoNewline
Write-Host "$outXlsxName written for your review" -ForegroundColor Green