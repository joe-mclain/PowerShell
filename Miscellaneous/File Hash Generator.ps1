<#
.SYNOPSIS
    Computes and displays the SHA-256 hash of a user-specified file.

.DESCRIPTION
    Prompts for a full file path, validates that the file exists, then calculates its SHA-256 hash using Get-FileHash and prints the algorithm, path, and hash; otherwise reports an invalid path.

.NOTES
- Created 2023.08.19 by Joe McLain (joe@bvu.edu)
- Last modified 2024.02.21 at 0914 by Joe McLain (joe@bvu.edu)
#>


$filePath = Read-Host -Prompt "Please enter the file path and name (e.g., C:\Files\YourFileName.extension)"
if (Test-Path -Path $filePath) {
    $fileHash = Get-FileHash -Path $filePath -Algorithm SHA256
    Write-Host "The $($fileHash.Algorithm) hash of the file $($fileHash.Path) is $($fileHash.Hash)"
} else {
    Write-Host "The file path you entered is invalid or the file does not exist."
}