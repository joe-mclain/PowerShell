<# ================================================================================================
.SYNOPSIS
    Tests Intune user-context deployment and EPM interaction

.DESCRIPTION
    The script performs three actions:
    1. Displays a non-interactive Windows Forms pop-up window with a custom message that automatically closes after 5 seconds.
    2. Creates 'LittleGuy.txt' in the current user's OneDrive Desktop path.
    3. Creates 'BigGuy.txt' on the All Users Desktop, intended to test EPM elevation/interaction.

.NOTES
    Created 2025.10.02 by Joe McLain (joe@bvu.edu)
    Modified 2025.10.02 at 0933 by Joe McLain (joe@bvu.edu)
================================================================================================
#>

# Get the current date and time for file content
$CurrentDateTime = Get-Date -Format "MM/dd/yyyy at HH:mm:ss"
$FileContent = "Successfully created on $CurrentDateTime"

### --- Start a temporary, non-interactive pop-up window (5 seconds) ---

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to create and auto-close the pop-up
function Show-TimedPopup {
    param(
        [string]$Message,
        [int]$DurationSeconds
    )

    # Create the main form (the pop-up window)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "System Notification"
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle # Non-resizable
    $form.MaximizeBox = $false # Prevent maximizing
    $form.MinimizeBox = $false # Prevent minimizing
    $form.TopMost = $true # Keep on top of other windows

    # Create the label for the message
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Location = New-Object System.Drawing.Point(20, 30)
    $label.Size = New-Object System.Drawing.Size(350, 60)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $form.Controls.Add($label)

    # Create a timer to close the form automatically
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $DurationSeconds * 1000 # Convert seconds to milliseconds
    
    # Define the action for the timer tick (close the form)
    $timer.Add_Tick({
        # Stop the timer and close the form safely
        $timer.Stop()
        $form.Close()
    })
    
    # Start the timer and display the form
    $timer.Start()
    [void]$form.ShowDialog() # Display the pop-up and wait for it to close (either manually or by timer)

    # Clean up the timer object
    $timer.Dispose()
}

### Call the function to display the pop-up for 5 seconds
Show-TimedPopup -Message "Hi there! It's nice to see you!" -DurationSeconds 5

### --- Create file in the user's OneDrive Desktop folder ---
$UserOneDriveDesktopPath = Join-Path -Path $env:USERPROFILE -ChildPath "OneDrive - Buena Vista University\Desktop"
$LittleGuyFilePath = Join-Path -Path $UserOneDriveDesktopPath -ChildPath "LittleGuy.txt"

# Ensure the target directory exists before trying to create the file
if (-not (Test-Path -Path $UserOneDriveDesktopPath -PathType Container)) {
    # If the path doesn't exist, create it.
    New-Item -Path $UserOneDriveDesktopPath -ItemType Directory -Force
}

# Create the file
$FileContent | Out-File -FilePath $LittleGuyFilePath -Force

### --- Create file on the All Users Desktop ---
$AllUsersDesktopPath = Join-Path -Path $env:PUBLIC -ChildPath "Desktop"
$BigGuyFilePath = Join-Path -Path $AllUsersDesktopPath -ChildPath "BigGuy.txt"

$FileContent | Out-File -FilePath $BigGuyFilePath -Force