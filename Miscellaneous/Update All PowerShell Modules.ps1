<#
.SYNOPSIS
    Updates all installed modules for both Windows PowerShell 5 and PowerShell 7, including a PS5 bootstrap if PackageManagement/PowerShellGet are missing, then prints a single consolidated update summary.

.DESCRIPTION
    The script:
      • Verifies elevation and locates pwsh.exe for PS7.
      • Bootstraps Windows PowerShell 5 by ensuring PackageManagement/PowerShellGet are present (with a fallback that downloads from PowerShell Gallery if needed) and normalizes PSModulePath.
      • Runs module updates separately in PS5 and PS7 hosts, checking each installed module against the gallery and updating when newer versions exist.
      • Collects results from both hosts and outputs a concise table of modules that changed (old → new), or states that no updates were required.

.NOTES
- Created 2025.07.30 by Joe McLain (joe@bvu.edu)
- Last modified 2025.07.30 at 0930 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Update all installed PowerShell 5 and 7 modules..." -ForegroundColor Blue
Write-Host

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host
    Write-Host "Please run this script as an administrator." -ForegroundColor Red
    exit 1
}

$updatedModules = [System.Collections.ArrayList]::new()

function Get-PwshExe {
    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "$env:ProgramFiles(x86)\PowerShell\7\pwsh.exe"
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    try { (Get-Command pwsh.exe -ErrorAction Stop).Source } catch { $null }
}
$Global:PwshExe = Get-PwshExe

function Ensure-PackageManagementForPS5 {
    $ps5Exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (-not (Test-Path $ps5Exe)) {
        Write-Host "Windows PowerShell 5 not found; skipping PS5 bootstrap." -ForegroundColor Yellow
        return $false
    }

    Write-Host "Bootstrapping PackageManagement & PowerShellGet for PS 5…" -ForegroundColor DarkYellow

    $bootstrap = @'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$env:PSModulePath = ($env:PSModulePath -split ';' | Where-Object { $_ -notmatch '\\WindowsApps\\' }) -join ';'

$fullCLR = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
if (-not (Test-Path $fullCLR)) {
    New-Item -Path $fullCLR -ItemType Directory -Force | Out-Null
}
if ($env:PSModulePath.Split(';')[0] -ne $fullCLR) {
    $env:PSModulePath = "$fullCLR;$env:PSModulePath"
}

$pmImported = $false
try {
    Import-Module PackageManagement -MinimumVersion 1.4.6 -Force -ErrorAction Stop
    $pmImported = $true
} catch {
    $currentError = $_
    Write-Host ("PackageManagement not directly importable: " + $currentError.Exception.Message) -ForegroundColor DarkYellow
}

$pgImported = $false
try {
    Import-Module PowerShellGet -MinimumVersion 2.2.5 -Force -ErrorAction Stop
    $pgImported = $true
} catch {
    $currentError = $_
    Write-Host ("PowerShellGet not directly importable: " + $currentError.Exception.Message) -ForegroundColor DarkYellow
}

if (-not ($pmImported -and $pgImported)) {
    Write-Host "PackageManagement and/or PowerShellGet not available. Attempting manual download and install." -ForegroundColor Yellow
    $tmpDownloadDir = Join-Path $env:TEMP 'PowerShellModulesBootstrap'
    if (-not (Test-Path $tmpDownloadDir)) {
        New-Item -Path $tmpDownloadDir -ItemType Directory -Force | Out-Null
    }

    $modulesToDownload = @(
        @{Name = 'PackageManagement'; Version = '1.4.6'},
        @{Name = 'PowerShellGet'; Version = '2.2.5'}
    )

    foreach ($moduleInfo in $modulesToDownload) {
        $moduleName = $moduleInfo.Name
        $moduleVersion = $moduleInfo.Version
        $nupkgUrl = "https://www.powershellgallery.com/api/v2/package/$moduleName/$moduleVersion"
        $nupkgPath = Join-Path $tmpDownloadDir "$moduleName.$moduleVersion.nupkg"
        $moduleTargetPath = Join-Path $fullCLR $moduleName

        Write-Host "Downloading $moduleName version $moduleVersion..." -ForegroundColor DarkYellow
        try {
            Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -ErrorAction Stop
            
            if (Test-Path $moduleTargetPath) {
                Write-Host "Clearing existing module directory: $moduleTargetPath..." -ForegroundColor DarkYellow
                Remove-Item $moduleTargetPath -Recurse -Force -ErrorAction SilentlyContinue
            }
            New-Item -Path $moduleTargetPath -ItemType Directory -Force | Out-Null

            Write-Host "Extracting $moduleName to $moduleTargetPath..." -ForegroundColor DarkYellow
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($nupkgPath, $moduleTargetPath)
        } catch {
            $currentError = $_
            Write-Host ("Failed to download or extract " + $moduleName + ": " + $currentError.Exception.Message) -ForegroundColor Red
            Remove-Item $tmpDownloadDir -Recurse -Force -ErrorAction SilentlyContinue
            exit 1
        }
    }
    Remove-Item $tmpDownloadDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Attempting to import modules after manual installation." -ForegroundColor DarkYellow
    try {
        Import-Module PackageManagement -MinimumVersion 1.4.6 -Force -ErrorAction Stop
        Import-Module PowerShellGet -MinimumVersion 2.2.5 -Force -ErrorAction Stop
    } catch {
        $currentError = $_
        Write-Host ("Failed to import PackageManagement or PowerShellGet after manual installation: " + $currentError.Exception.Message) -ForegroundColor Red
        exit 1
    }
}

if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSGallery repository." -ForegroundColor DarkYellow
    Register-PSRepository -Default -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2 -InstallationPolicy Trusted -Force
}

Write-Host "PS 5 bootstrap complete; PackageManagement / PowerShellGet ready." -ForegroundColor Green
exit 0
'@

    $tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName() + '.ps1')
    $bootstrap | Set-Content $tmp -Encoding utf8
    $p = Start-Process -FilePath $ps5Exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$tmp) -Wait -PassThru -NoNewWindow
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return ($p.ExitCode -eq 0)
}

function Write-TempScript {
    param (
        [string]$Tag,
        [string]$Json
    )
@'
function Update-ModulesInScope {
    param([string]$Version, [string]$OutJson)

    Write-Host
    Write-Host "Current PowerShell $Version version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkCyan

    if ($Version -eq '5') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $fullCLR = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
        
        Add-Type -AssemblyName System.Runtime.InteropServices
        $shell = New-Object -ComObject WScript.Shell
        $documentsPath = $shell.SpecialFolders.Item("MyDocuments")
        $userModulePath = Join-Path $documentsPath 'WindowsPowerShell\Modules'

        Write-Host "Diagnostic: User module path resolved to: $userModulePath" -ForegroundColor DarkGray
        Write-Host "Diagnostic: Does user module path exist? $(Test-Path $userModulePath)" -ForegroundColor DarkGray

        if ($env:PSModulePath.Split(';')[0] -ne $fullCLR) {
            $env:PSModulePath = "$fullCLR;$env:PSModulePath"
        }
        if (Test-Path $userModulePath) {
            if ($env:PSModulePath -notlike "*$userModulePath*") {
                $env:PSModulePath = "$userModulePath;$env:PSModulePath"
            }
        }
        Write-Host "Diagnostic: Final PSModulePath for PS5: $($env:PSModulePath)" -ForegroundColor DarkGray
    }

    try {
        Import-Module PackageManagement -Force -ErrorAction Stop
        Import-Module PowerShellGet -Force -ErrorAction Stop
    } catch {
        $currentError = $_
        Write-Host ("Failed to import PackageManagement or PowerShellGet in PowerShell " + $Version + ": " + $currentError.Exception.Message) -ForegroundColor Red
        Write-Host "Skipping module updates for PowerShell " + $Version + "." -ForegroundColor Red
        [System.Collections.ArrayList]::new() | ConvertTo-Json -Compress | Set-Content $OutJson -Encoding utf8
        return
    }

    if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
        Write-Host "Install-Module cmdlet not found in PowerShell " + $Version + ". Skipping module updates." -ForegroundColor Red
        [System.Collections.ArrayList]::new() | ConvertTo-Json -Compress | Set-Content $OutJson -Encoding utf8
        return
    }

    $updated = [System.Collections.ArrayList]::new()
    $installedViaPSGet = Get-InstalledModule -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    Write-Host "Diagnostic: Modules recognized by Get-InstalledModule (PS$Version): $($installedViaPSGet -join ', ')" -ForegroundColor DarkGray


    if ($Version -eq '5') {
        $unrecognizedModules = @()
        if (Test-Path $userModulePath) {
            $modulesOnDiskUserPathNames = Get-ChildItem -Path $userModulePath -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique
            Write-Host "Diagnostic: Modules found on disk in user path (PS5): $($modulesOnDiskUserPathNames -join ', ')" -ForegroundColor DarkGray
            
            # Filter out the meta-modules "Az" and "Microsoft.Graph" from the unrecognized list
            $modulesToConsiderForReinstall = $modulesOnDiskUserPathNames | Where-Object { 
                $_ -notin $installedViaPSGet -and 
                $_ -ne 'Az' -and 
                $_ -ne 'Microsoft.Graph'
            }
            $unrecognizedModules = $modulesToConsiderForReinstall
            
            Write-Host "Diagnostic: Unrecognized modules (excluding meta-modules) found in user path (PS5): $($unrecognizedModules -join ', ')" -ForegroundColor DarkGray
        }

        if ($unrecognizedModules.Count -gt 0) {
            Write-Host "Attempting to register/reinstall $($unrecognizedModules.Count) individual modules found on disk but not via Get-InstalledModule..." -ForegroundColor DarkYellow
            foreach ($moduleName in $unrecognizedModules) {
                Write-Host "Registering/Reinstalling: $moduleName..." -ForegroundColor DarkYellow
                try {
                    Install-Module -Name $moduleName -Force -AllowClobber -SkipPublisherCheck -Scope CurrentUser -Confirm:$false -ErrorAction Stop
                    Write-Host "Successfully registered $moduleName." -ForegroundColor Green
                } catch {
                    $currentError = $_
                    Write-Host ("Failed to register/reinstall " + $moduleName + ": " + $currentError.Exception.Message) -ForegroundColor Red
                }
            }
            $installedViaPSGet = Get-InstalledModule -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        }
    }


    $installed = Get-InstalledModule -ErrorAction SilentlyContinue
    if (-not $installed) {
        Write-Host "No modules found to update in PowerShell $Version." -ForegroundColor Yellow
        $updated | ConvertTo-Json -Compress | Set-Content $OutJson -Encoding utf8
        return
    }

    foreach ($m in $installed) {
        $name, $old = $m.Name, $m.Version
        $latest = (Find-Module -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1).Version
        if (-not $latest) { Write-Host "No gallery entry for $name."; continue }

        Write-Host "Checking: $name (Current: $old, Latest: $latest)"
        if ($old -lt $latest) {
            try {
                Update-Module -Name $name -Force
                $new = (Get-InstalledModule -Name $name).Version
                Write-Host ("Updated: " + $name + " " + $old + " -> " + $new) -ForegroundColor Green
                $updated.Add([pscustomobject]@{PS_Version=$Version;Module_Name=$name;Starting_Version=$old;Ending_Version=$new})|Out-Null
            } catch {
                $currentError = $_
                Write-Host ("FAILED: " + $name + " : " + $currentError.Exception.Message) -ForegroundColor Red
            }
        } else {
            Write-Host "Module " + $name + " already latest (" + $old + ")."
        }
    }

    $updated | ConvertTo-Json -Compress | Set-Content $OutJson -Encoding utf8
}
'@ + "`nUpdate-ModulesInScope -Version '$Tag' -OutJson '$Json'"
}

function Invoke-UpdateInHost {
    param($Exe,$Tag,$Temp,$Json)
    Write-Host
    Write-Host "--- Updating PowerShell $Tag modules using: $Exe" -ForegroundColor Cyan
    Start-Process -FilePath $Exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Temp) -NoNewWindow -Wait
    if (Test-Path $Json) {
        (Get-Content -Raw $Json | ConvertFrom-Json) | ForEach-Object { $updatedModules.Add($_) | Out-Null }
    }
}

function Update-PS5 {
    if (-not (Ensure-PackageManagementForPS5)) {
        Write-Host "Skipping PS5 updates due to bootstrap failure." -ForegroundColor Red
        return
    }
    $json = Join-Path $env:TEMP 'PS5_Update.json'
    $tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName()+'.ps1')
    Write-TempScript -Tag '5' -Json $json | Set-Content $tmp -Encoding utf8
    Invoke-UpdateInHost -Exe "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Tag '5' -Temp $tmp -Json $json
    Remove-Item $tmp,$json -ErrorAction SilentlyContinue
}

function Update-PS7 {
    if (-not $PwshExe) {
        Write-Host "PowerShell 7 not found; skipping PS7 updates." -ForegroundColor Red
        return
    }
    $json = Join-Path $env:TEMP 'PS7_Update.json'
    $tmp = Join-Path $env:TEMP ([IO.Path]::GetRandomFileName()+'.ps1')
    Write-TempScript -Tag '7' -Json $json | Set-Content $tmp -Encoding utf8
    Invoke-UpdateInHost -Exe $PwshExe -Tag '7' -Temp $tmp -Json $json
    Remove-Item $tmp,$json -ErrorAction SilentlyContinue
}

Update-PS5
Update-PS7

Write-Host
Write-Host "## Module Update Summary" -ForegroundColor Blue
if ($updatedModules.Count) {
    Write-Host "The following modules were updated:" -ForegroundColor Green
    $updatedModules |
        Sort-Object PS_Version,Module_Name |
        Format-Table PS_Version,Module_Name,Starting_Version,Ending_Version -AutoSize
} else {
    Write-Host "No modules required updating." -ForegroundColor Yellow
}