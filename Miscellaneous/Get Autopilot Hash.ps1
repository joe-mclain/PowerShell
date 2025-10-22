<#
.SYNOPSIS
    Generates and saves the device’s Windows Autopilot hardware hash to a CSV named after the computer, using Get-WindowsAutopilotInfo.

.DESCRIPTION
    Sets a TLS 1.2 session, uses the script’s folder as the working directory, and ensures it exists. Temporarily allows script execution for the process, adds the standard Scripts path to PATH, installs the Get-WindowsAutopilotInfo tool if needed, then runs it to create "<COMPUTERNAME>_APHash.csv" in the script directory. Emits clear success/error messages.

.NOTES
- Created 2023.08.24 by Joe McLain (joe@bvu.edu)
- Last modified 2024.06.13 at 1413 by Joe McLain (joe@bvu.edu)
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define the directory path as the script's location
$DirectoryPath = $PSScriptRoot

# Check if the directory exists, if not, create it
if (-not (Test-Path -Path $DirectoryPath)) {
    New-Item -Type Directory -Path $DirectoryPath -ErrorAction SilentlyContinue
}

Set-Location -Path $DirectoryPath
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

# Install the script with verbose output
Install-Script -Name Get-WindowsAutopilotInfo -Force -ErrorAction SilentlyContinue -Verbose

# Get the computer name
$ComputerName = $env:COMPUTERNAME

# Ensure $ComputerName is not null or empty
if (-not [string]::IsNullOrEmpty($ComputerName)) {
    # Try to generate the output file
    Try {
        $OutputFilePath = "$DirectoryPath\$ComputerName`_APHash.csv"
        Get-WindowsAutopilotInfo -OutputFile $OutputFilePath -Verbose
        Write-Output "Output file generated successfully at $OutputFilePath"
    } Catch {
        Write-Error "Failed to generate the output file: $_"
    }
} else {
    Write-Error "The computer name could not be determined. The output file cannot be generated."
}