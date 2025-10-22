<#
.SYNOPSIS
    Creates a directory symbolic link, after validating the target exists and the link path is safe to use.

.DESCRIPTION
    Prompts for an existing target folder and a desired link path, warns if the link path already contains files, and attempts to create a directory symlink (SymbolicLink). Repeats until successful or corrected input is provided. Requires administrative rights or Windows Developer Mode for symlink creation.

.NOTES
- Created 2024.09.02 by Joe McLain (joe@bvu.edu)
- Last modified 2024.09.05 at 1315 by Joe McLain (joe@bvu.edu)
#>

# Clear the screen to make it easy to see the output of each run
Clear-Host

while ($true) {
    # Prompt for the target folder path
    $TargetPath = Read-Host "Enter the full path to the existing target folder containing the files you want to link to"

    # Check if the target folder exists
    if (-Not (Test-Path -Path $TargetPath -PathType Container)) {
        Write-Host
	Write-Host "The target folder does not exist. Please check the path and try again." -ForegroundColor Red
        continue
    }

    # Prompt for the link folder path
    $LinkPath = Read-Host "Enter the full path for the desired symbolic link"

    # Check if the link folder exists
    if (Test-Path -Path $LinkPath -PathType Container) {
        # Check if the link folder contains any files
        if (Get-ChildItem -Path $LinkPath | Where-Object { $_.PSIsContainer -eq $false }) {
            Write-Host
            Write-Host "The link folder already exists and contains files. Please choose a different path." -ForegroundColor Red
            continue
        }
    }

    # Create the symbolic link
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath
        Write-Host
	Write-Host "Symbolic link created successfully from '$LinkPath' to '$TargetPath'." -ForegroundColor Green
        break
    } catch {
        Write-Host
	Write-Host "An error occurred while creating the symbolic link: $_" -ForegroundColor Red
        continue
    }
}
