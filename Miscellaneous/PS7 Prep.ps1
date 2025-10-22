<#
.SYNOPSIS
    Preps a technician workstation for PowerShell 7 scripting: verifies prerequisites, configures package sources, installs core modules/tools, and updates the environment.

.DESCRIPTION
    The script:
      • Ensures it’s running in PowerShell 7 and as Administrator.
      • Sets TLS 1.2 and registers PowerShell Gallery as a trusted repository.
      • Refreshes PackageManagement/PowerShellGet (in a separate elevated session).
      • Installs core modules (Microsoft.Graph, Az) and updates all installed modules.
      • Creates the user PowerShell profile directory if missing.
      • Installs Git silently if not present; initiates VS Code install via Microsoft Store if not present.
      • Prints clear status for each step and a completion message.

.NOTES
- Created 2024.09.16 by Joe McLain (joe@bvu.edu)
- Last modified 2024.11.19 at 1631 by Joe McLain (joe@bvu.edu)
#>

# Clear the screen to make it easy to see the output of each run
Clear-Host
Write-Host
Write-Host "Preparing system for PowerShell 7 scripting..." -ForegroundColor Blue
Write-Host

# This script is to be run in PowerShell 7 so it can be properly configured
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please install PowerShell 7 from the Microsoft Store." -ForegroundColor Red
    $storeUri = "ms-windows-store://pdp/?productid=9MZ1SNWT0N5D"
    Start-Process -FilePath $storeUri
    exit
}

# Confirm script is running as Administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "This script must be run as Administrator. Please restart PowerShell as Administrator and run the script again." -ForegroundColor Red
    exit
}

# Set TLS protocol to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ensure the PowerShell Gallery repository is registered
Write-Host
Write-Host "Configuring PowerShell Gallery repository..." -ForegroundColor Blue
if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
    Write-Host "Registering PSGallery repository..." -ForegroundColor Blue
    Register-PSRepository -Default
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Update PowerShellGet and NuGet Provider
function Update-Modules {
    param()

    # Build the script block to update modules
    $scriptBlock = {
        # Ensure TLS 1.2 is used
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Set Execution Policy to RemoteSigned for current user
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

        # Register PSGallery if not already registered
        if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
            Register-PSRepository -Default -ErrorAction Stop
        }
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop

        # Install or update PackageManagement module
        Install-Module -Name PackageManagement -MinimumVersion 1.4.8.1 -Force -AllowClobber

        # Install or update PowerShellGet module
        Install-Module -Name PowerShellGet -MinimumVersion 2.2.5 -Force -AllowClobber

        # Install NuGet provider
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    }

    # Convert the script block to a string and escape double quotes
    $script = $scriptBlock.ToString().Replace('"', '""')

    # Determine the PowerShell executable (pwsh for PowerShell 7+, powershell for Windows PowerShell 5.1)
    $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue) ? 'pwsh' : 'powershell'

    # Start a new elevated PowerShell process to run the update script
    Write-Host "Updating PackageManagement and PowerShellGet modules in a new session..." -ForegroundColor Blue
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $psExe
    $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& {$script}`""
    $startInfo.Verb = "RunAs"
    $startInfo.UseShellExecute = $true

    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Host "Failed to update modules in the new session." -ForegroundColor Green
        exit
    } else {
        Write-Host "Modules updated successfully in the new session." -ForegroundColor Green
    }
}

# Install Required Modules
Write-Host
Write-Host "Installing required modules..." -ForegroundColor Blue
$requiredModules = @('Microsoft.Graph', 'Az')

foreach ($module in $requiredModules) {
    try {
        if (-not (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)) {
            Write-Host "Installing module: $module..." -ForegroundColor Yellow
            Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "Module '$module' installed successfully." -ForegroundColor Green
        } else {
            Write-Host "Module '$module' is already installed." -ForegroundColor Green
        }

        if (-not (Get-Module -ListAvailable -Name $module | Where-Object { $_.Name -eq $module })) {
            Write-Host "Importing module '$module'..." -ForegroundColor Yellow
            Import-Module -Name $module -ErrorAction Stop
            Write-Host "Module '$module' imported successfully." -ForegroundColor Green
        }
    } catch {
        Write-Host "Failed to install or import module '$module'. Error: $_" -ForegroundColor Red
        exit
    }
}

# Update all installed modules
Write-Host
Write-Host "Updating all installed modules. This could take a while..." -ForegroundColor Blue
Try {
    Get-InstalledModule | Update-Module -ErrorAction Stop
    Write-Host "All modules updated successfully." -ForegroundColor Green
} Catch {
    Write-Host "Failed to update modules." -ForegroundColor Green
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

# Ensure the folder hosting the PowerShell profile directory exists
Write-Host "Creating PowerShell profile directory..." -ForegroundColor Blue
Try {
    $profileDir = [System.IO.Path]::GetDirectoryName($PROFILE)
    if (!(Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force -ErrorAction Stop
        Write-Host "PowerShell profile directory created at $profileDir." -ForegroundColor Green
    } else {
        Write-Host "PowerShell profile directory already exists at $profileDir." -ForegroundColor Green
    }
} Catch {
    Write-Host "Failed to create PowerShell profile directory." -ForegroundColor Green
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

# Determine whether Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found. Installing Git..."
    $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.2/Git-2.47.0.2-64-bit.exe"
    $gitInstaller = "$env:TEMP\Git-2.47.0.2-64-bit.exe"
    Invoke-WebRequest -Uri $gitUrl -OutFile $gitInstaller
    Start-Process -FilePath $gitInstaller -ArgumentList "/VERYSILENT" -Wait
    Remove-Item -Path $gitInstaller -Force
    Write-Host "Git installed successfully."
} else {
    Write-Host "Git is already installed."
}

# Determine whether VS Code is installed
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "VS Code not found. Installing VS Code from the Microsoft Store..."
    $storeUri = "ms-windows-store://pdp/?productid=9NBLGGH4N4N3"
    Start-Process -FilePath $storeUri -Wait
    Write-Host "VS Code installation initiated. Please complete the installation from the Microsoft Store."
} else {
    Write-Host "VS Code is already installed."
}

# Actions complete
Write-Host
Write-Host "System preparation is complete." -ForegroundColor Green