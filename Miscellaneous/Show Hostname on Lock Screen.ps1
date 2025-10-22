<#
.SYNOPSIS
    Create and set a lock screen image displaying the computer's hostname

.DESCRIPTION
    Looks up the computer's hostname
    Creates a JPG image with black background and the hostname centered on it 
    Pokes the registry so the computer uses the new file as the default lock screen

.NOTES
    This script requires PowerShell 7 and admin privileges

    Created 2024.07.25 by Joe McLain (joe@bvu.edu)
    Updated on 2025.10.20 at 1210 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Creating and assigning hostname as lock screen image..."
Write-Host


# Check for PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script is optimized for PowerShell 7. Please run it in PowerShell 7 for best performance."
    exit
}

# Load the System.Drawing.Common assembly
Add-Type -AssemblyName System.Drawing

# Get the hostname of the computer
$hostname = $env:COMPUTERNAME

# Define the image path
$imagePath = "C:\Windows\System32\HostNameLockScreen.jpg"

# Create a new bitmap image
$width = 1920
$height = 1080
$bitmap = New-Object System.Drawing.Bitmap $width, $height

# Define the graphics object
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

# Set the background color
$backgroundColor = [System.Drawing.Color]::Black
$graphics.Clear($backgroundColor)

# Define the font and brush
$font = New-Object System.Drawing.Font("Arial", 48)
$brush = [System.Drawing.Brushes]::White

# Calculate the size of the text
$textSize = $graphics.MeasureString($hostname, $font)

# Calculate the position to center the text
$x = ($width - $textSize.Width) / 2
$y = ($height - $textSize.Height) / 2

# Draw the text
$graphics.DrawString($hostname, $font, $brush, $x, $y)

# Save the image
$bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

# Dispose of the graphics object
$graphics.Dispose()
$bitmap.Dispose()

# Create the registry path if it doesn't exist
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
if (-not (Test-Path $regPath)) {
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "Personalization"
}

# Set the lock screen image via registry
Set-ItemProperty -Path $regPath -Name "LockScreenImage" -Value $imagePath

# Enable the lock screen image policy
Set-ItemProperty -Path $regPath -Name "NoLockScreen" -Value 0 -Type DWord