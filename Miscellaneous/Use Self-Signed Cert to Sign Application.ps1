<#
.SYNOPSIS
    Creates a self-signed code-signing certificate, stores its artifacts in Azure Key Vault, and signs a specified application.

.DESCRIPTION
    Runs in PowerShell 7 with local admin rights. The script:
      • Validates the target executable path and prompts for an application name.
      • Ensures signtool.exe is available (installs the Windows SDK via winget if needed).
      • Authenticates to Azure, lets you choose a Key Vault, and generates a strong password.
      • Creates a self-signed code-signing certificate, exports .cer and .pfx, and signs the app.
      • Stores the password and certificate artifacts (.cer/.pfx) in the selected Key Vault.

.NOTES
- Created 2024.08.07 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.24 at 1123 by Joe McLain (joe@bvu.edu)
#>

# Clear the screen for improved readability
Clear-Host

# Ensure the script is running in PowerShell 7 or later
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7 or later. Please rerun this script in PowerShell 7." -ForegroundColor Red
    exit
}

# Ensure the script is running as local admin
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($currentUser)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator. Please restart PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# Function to validate non-blank user input with proper error handling
function Get-ValidatedInput {
    param (
        [string]$promptMessage,
        [string]$errorMessage = "Input cannot be blank. Please enter a valid value."
    )
    $inputValue = $null
    do {
        Write-Host $promptMessage -ForegroundColor Cyan -NoNewLine
        $inputValue = Read-Host
        if (-not [string]::IsNullOrWhiteSpace($inputValue)) {
            return $inputValue
        } else {
            Write-Host $errorMessage -ForegroundColor Red
        }
    } while (-not [string]::IsNullOrWhiteSpace($inputValue))
}

# Function to automatically generate a random 40-character password without problematic characters
function Generate-RandomPassword {
    $allowedChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+'
    $password = -join ((1..40) | ForEach-Object { $allowedChars.Substring((Get-Random -Minimum 0 -Maximum $allowedChars.Length), 1) })
    return $password
}

# Function to check for signtool.exe in Windows SDK
function Check-Signtool {
    $signtoolPaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\x64\signtool.exe",
        "C:\Program Files\Windows Kits\10\bin\x64\signtool.exe"
    )

    foreach ($path in $signtoolPaths) {
        if (Test-Path -Path $path) {
            Write-Host "signtool.exe found at: $path" -ForegroundColor Green
            return $path
        }
    }

    # Search entire C:\ drive as a fallback if signtool isn't found in default paths
    $signtoolLocation = Get-ChildItem -Path "C:\" -Filter "signtool.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($signtoolLocation) {
        Write-Host "signtool.exe found at: $($signtoolLocation.FullName)" -ForegroundColor Green
        return $signtoolLocation.FullName
    } else {
        Write-Host "signtool.exe not found. Please ensure the Windows SDK is installed and the path to signtool.exe is correct." -ForegroundColor Red
        return $null
    }
}

# Function to install the latest Windows SDK using winget
function Install-WindowsSDK {
    Write-Host
    Write-Host "Checking for the presence of the Windows SDK and signtool.exe utility..." -ForegroundColor Cyan

    # First, check for signtool.exe presence
    $signtoolPath = Check-Signtool
    if ($signtoolPath) {
        return $signtoolPath
    }

    # If signtool.exe is not found, proceed to install the latest Windows SDK
    Write-Host "signtool.exe was not found; installing the latest Windows SDK..." -ForegroundColor Yellow
    try {
        # Run the winget search command and capture the output
        $wingetOutput = winget search "Microsoft.WindowsSDK"

        # Convert the output to an array of lines
        $lines = $wingetOutput -split "`n"

        # Filter out the lines that contain the SDK versions
        $sdkLines = $lines | Where-Object { $_ -match "Microsoft.WindowsSDK" }

        # Create an array to store the SDK information
        $sdkList = @()

        # Process each line to extract the Id and Version
        foreach ($line in $sdkLines) {
            $columns = $line -split "\s{2,}"
            $sdkList += [PSCustomObject]@{
                Id = $columns[1]
                Version = $columns[2]
            }
        }

        # Sort the SDK list by Version in ascending order
        $sdkList = $sdkList | Sort-Object -Property Version -Descending

        # Extract the Id without the version number
        $winSdkId = $sdkList[0].Id -replace "\s+\d+\.\d+\.\d+\.\d+$"

        # Install the latest version of the SDK
        Write-Host "Installing Windows SDK via winget ($winSdkId). This may take a while so please be patient..." -ForegroundColor Yellow
        winget install --id $winSdkId --silent --accept-package-agreements --accept-source-agreements
        Write-Host "Windows SDK installed successfully. Rechecking for signtool.exe..." -ForegroundColor Green

        # Recheck for signtool.exe after installation
        $signtoolPath = Check-Signtool
        if ($signtoolPath) {
            return $signtoolPath
        } else {
            throw "signtool.exe still not found after SDK installation."
        }
    } catch {
        Write-Host "Windows SDK installation failed. Exiting." -ForegroundColor Red
        exit 1
    }
}

# Run the SDK installation check
$signtoolPath = Install-WindowsSDK
if (-not $signtoolPath) {
    Write-Host "signtool.exe is required for signing the application. Exiting." -ForegroundColor Red
    exit 1
}

# Azure Key Vault and subscription details
Write-Host
Write-Host "Logging in to Azure..." -ForegroundColor Cyan
Connect-AzAccount -ErrorAction Stop

# Retrieve subscription and tenant ID automatically
$context = Get-AzContext
$tenantId = $context.Tenant.Id
$subscriptionId = $context.Subscription.Id

Write-Host "Retrieved Tenant ID: $tenantId" -ForegroundColor DarkCyan
Write-Host "Retrieved Subscription ID: $subscriptionId" -ForegroundColor DarkCyan

# List available Key Vaults and prompt for selection
Write-Host
Write-Host "Retrieving list of Azure Key Vaults..." -ForegroundColor Cyan
$keyVaults = Get-AzKeyVault | Select-Object -Property VaultName

if ($keyVaults.Count -eq 0) {
    Write-Host "No Key Vaults found in this subscription." -ForegroundColor Red
    exit 1
}

# Display the Key Vaults in a numbered list for user selection
$counter = 1
foreach ($vault in $keyVaults) {
    Write-Host "$counter. $($vault.VaultName)"
    $counter++
}

# Prompt user for selection of Key Vault
do {
    $selectionIndex = Get-ValidatedInput "Please select a Key Vault by number: " "Please select a valid number from the list."
    if ($selectionIndex -match '^\d+$' -and $selectionIndex -gt 0 -and $selectionIndex -le $keyVaults.Count) {
        $selectedVault = $keyVaults[$selectionIndex - 1].VaultName
        Write-Host
        Write-Host "You have selected Key Vault: $selectedVault" -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Invalid selection. Please enter a valid number from the list." -ForegroundColor Red
    }
} while (-not $selectedVault)

# Prompt user for the application path and validate
do {
    Write-Host
    $appPath = Get-ValidatedInput "Please enter the path to the directory containing file you wish to sign: "
    $appFilename = Get-ValidatedInput "Please enter the filename of the target file: "
    $appFullPath = Join-Path -Path $appPath -ChildPath $appFilename

    if (-not (Test-Path -Path $appFullPath -PathType Leaf)) {
        Write-Host "The specified file does not exist. Please check the path and try again." -ForegroundColor Red
    }
} while (-not (Test-Path -Path $appFullPath -PathType Leaf))

# Prompt user for the application name
do {
    $AppName = Get-ValidatedInput "Please enter the Application name (letters and numbers only): "
    if ($AppName -match '[^a-zA-Z0-9]') {
        Write-Host "The application name contains invalid characters. Please use only letters and numbers." -ForegroundColor Red
    }
} while ($AppName -match '[^a-zA-Z0-9]')

# Generate a strong password for the certificate
$passwordText = Generate-RandomPassword
$securePassword = $passwordText | ConvertTo-SecureString -AsPlainText -Force

# Define certificate storage paths
$documentsPath = [Environment]::GetFolderPath("MyDocuments")
$certificatesPath = Join-Path -Path $documentsPath -ChildPath "Certificates"
if (-not (Test-Path -Path $certificatesPath)) {
    New-Item -Path $certificatesPath -ItemType Directory | Out-Null
}

$certPath = Join-Path -Path $certificatesPath -ChildPath "$AppName.cer"
$pfxPath = Join-Path -Path $certificatesPath -ChildPath "$AppName.pfx"

# Create self-signed certificate with cryptographic provider compatibility
Write-Host
Write-Host "Creating self-signed certificate..." -ForegroundColor Cyan
try {
    $cert = New-SelfSignedCertificate -Subject "CN=$AppName" -CertStoreLocation cert:\CurrentUser\My -FriendlyName "$AppName-Cert" `
                                      -KeyExportPolicy Exportable -Type CodeSigningCert -KeySpec Signature -KeyAlgorithm RSA `
                                      -KeyLength 2048 -HashAlgorithm SHA256 `
                                      -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
                                      -NotAfter (Get-Date).AddYears(2)
    Write-Host "Certificate created successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to create certificate: $_" -ForegroundColor Red
    exit 1
}

# Export the certificate to a .CER file
Write-Host
Write-Host "Exporting certificate to .CER file..." -ForegroundColor Cyan
try {
    Export-Certificate -Cert $cert -FilePath $certPath
    Write-Host "Certificate exported to .CER file successfully. Location: $certPath" -ForegroundColor Green
} catch {
    Write-Host "Failed to export certificate: $_" -ForegroundColor Red
    exit 1
}

# Export the certificate to a .PFX file
Write-Host
Write-Host "Exporting certificate to .PFX file..." -ForegroundColor Cyan
try {
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword
    Write-Host "Certificate exported to .PFX file successfully. Location: $pfxPath" -ForegroundColor Green
} catch {
    Write-Host "Failed to export certificate: $_" -ForegroundColor Red
    exit 1
}

# Store the password in Azure Key Vault
Write-Host
Write-Host "Storing password in Azure Key Vault..." -ForegroundColor Cyan
try {
    Set-AzKeyVaultSecret -VaultName $selectedVault -Name "$AppName-Password" -SecretValue $securePassword
    Write-Host "Password stored in Azure Key Vault successfully." -ForegroundColor Green
    Write-Host "Password stored under name: $AppName-Password in Vault: $selectedVault" -ForegroundColor DarkCyan
} catch {
    Write-Host "Failed to store password: $_" -ForegroundColor Red
    exit 1
}

# Sign the application using signtool
Write-Host
Write-Host "Signing the application..." -ForegroundColor Cyan
try {
    $timestampServer = "http://timestamp.digicert.com"
    
    # Verify signtoolPath is valid
    if (-not (Test-Path $signtoolPath)) {
        throw "signtool.exe was not found at the specified path: $signtoolPath"
    }
    
    # Try signing the application
    $signCmd = "& `"$signtoolPath`" sign /f `"$pfxPath`" /p $passwordText /tr $timestampServer /td sha256 /fd sha256 `"$appFullPath`""
    Invoke-Expression $signCmd

    Write-Host "Application signed successfully. File: $appFullPath" -ForegroundColor Green
} catch {
    # Check if there's a module-related error
    if ($_ -match 'The module .* could not be loaded') {
        Write-Host "Failed to sign the application: Required module could not be loaded. Run 'Import-Module' for more information." -ForegroundColor Red
    } else {
        Write-Host "Failed to sign the application: $_" -ForegroundColor Red
    }
    exit 1
}


# Store the .PFX file in Azure Key Vault
Write-Host
Write-Host "Storing .PFX file in Azure Key Vault..." -ForegroundColor Cyan
try {
    $pfxPolicy = New-AzKeyVaultCertificatePolicy -IssuerName "Self" -ValidityInMonths 12 -SecretContentType "application/x-pkcs12" -SubjectName "CN=$AppName"
    Import-AzKeyVaultCertificate -VaultName $selectedVault -Name "$AppName-PFX" -FilePath $pfxPath -PolicyObject $pfxPolicy -Password $securePassword
    Write-Host ".PFX file stored in Azure Key Vault successfully." -ForegroundColor Green
    Write-Host "Stored under name: $AppName-PFX in Vault: $selectedVault" -ForegroundColor DarkCyan
} catch {
    Write-Host "Failed to store .PFX file: $_" -ForegroundColor Red
    exit 1
}