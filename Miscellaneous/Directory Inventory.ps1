<#
.SYNOPSIS
    Creates a single plain-text “inventory” of all .ps1 files in a chosen directory by concatenating each filename and its contents.

.DESCRIPTION
    Prompts for a target folder, derives "<FolderName> Inventory.txt" as the output file, and collects all .ps1 files (non-recursive).
    For each script it writes the file name, then the full file contents, separated by blank lines, producing one consolidated reference file.

.NOTES
- Created 2024.09.17 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.17 at 1734 by Joe McLain (joe@bvu.edu)
#>


# Ask the user for the full path of the target directory
$targetDirectory = Read-Host "Enter the full path of the target directory"

# Get the directory name to use in the output file name
$directoryName = Split-Path -Leaf $targetDirectory

# Define the output file name
$outputFile = "$directoryName Inventory.txt"

# Get a list of all PS1 files in the target directory
$ps1Files = Get-ChildItem -Path $targetDirectory -Filter *.ps1

# Create or clear the output file
Clear-Content -Path $outputFile -ErrorAction SilentlyContinue
New-Item -Path $outputFile -ItemType File -Force

# Loop through each PS1 file and append its name and contents to the output file
foreach ($file in $ps1Files) {
    $fileName = $file.Name
    $fileContent = Get-Content -Path $file.FullName

    Add-Content -Path $outputFile -Value $fileName
    Add-Content -Path $outputFile -Value $fileContent
    Add-Content -Path $outputFile -Value "`n`n`n`n`n"  # Add five blank lines
}

Write-Host "Inventory created: $outputFile"
