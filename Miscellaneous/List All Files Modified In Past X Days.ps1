<#
.SYNOPSIS
    Recursively finds files created or modified within a user-specified number of days starting from a chosen folder.

.DESCRIPTION
    Prompts for a top-level folder and an integer day window, computes a cutoff date, and scans the directory tree.
    Lists matching files (path, last modified, created) when found; otherwise reports that no files matched.

.NOTES
- Created 2025.07.25 by Joe McLain (joe@bvu.edu)
- Last modified 2025.07.25 at 0000 by Joe McLain (joe@bvu.edu)
#>

Clear-Host
Write-Host
Write-Host "Finding files created or modified within a specified number of days..."
Write-Host

# Prompt the user for the top folder to begin the search
Write-Host "Enter the top folder to begin the search: " -ForegroundColor Cyan -NoNewLine
$topFolder = Read-Host

# Prompt the user for the number of days to include in the scope
Write-Host "Enter the number of days to include in the scope: " -ForegroundColor Cyan -NoNewLine
$days = Read-Host

# Validate that the input is a number
if (-not ($days -match "^\d+$")) {
    Write-Host "Invalid input! Please enter a numeric value for days." -ForegroundColor Red
    exit
}

# Convert input to an integer
$days = [int]$days

# Determine the cutoff date for file modification/creation time
$cutoffDate = (Get-Date).AddDays(-$days)

# Display status message before starting the search
Write-Host "Searching for files modified or created in the last $days days..." -ForegroundColor Blue

# Retrieve files recursively that meet the modification or creation date criteria
$files = Get-ChildItem -Path $topFolder -Recurse -File | Where-Object {
    $_.LastWriteTime -ge $cutoffDate -or $_.CreationTime -ge $cutoffDate
}

# Determine whether any files were found within the specified date range
if ($files.Count -gt 0) {
    # Display success message and list matching files
    Write-Host "Files found:" -ForegroundColor Green
    $files | ForEach-Object {
        Write-Host "Path: $($_.DirectoryName)\$($_.Name)" -ForegroundColor Green
        Write-Host "  File Name: $($_.Name)" -ForegroundColor Green
        Write-Host "  Last Modified: $($_.LastWriteTime)" -ForegroundColor Green
        Write-Host "  Created: $($_.CreationTime)" -ForegroundColor Green
        Write-Host ""
    }
} else {
    # Display warning message if no files match the criteria
    Write-Host "No files found within the specified date range." -ForegroundColor Yellow
}
