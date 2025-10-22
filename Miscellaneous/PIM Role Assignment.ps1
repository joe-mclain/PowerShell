<#
.SYNOPSIS
    GUI-assisted activation of an eligible Entra ID (Azure AD) PIM role with justification for the maximum allowed duration.

.DESCRIPTION
    The script authenticates to Microsoft Graph, discovers the signed-in user’s eligible PIM roles, and displays a simple Windows Forms UI to:
      • Select a role and enter a justification
      • Submit a self-activate request (skips if the role is already active)
      • Use the tenant’s maximum permitted activation duration for that role
    On success, it confirms activation.

.NOTES
- Created 2024.09.25 by Joe McLain (joe@bvu.edu)
- Last modified 2024.10.03 at 1131 by Joe McLain (joe@bvu.edu)
#>

Clear-Host

# Install and import the required Microsoft.Graph modules if not already available
Write-Host
Write-Host "Checking for the requisite PowerShell modules..." -ForegroundColor Yellow
$requiredModules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Identity.Governance')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module..." -ForegroundColor Cyan
        Install-Module -Name $module -Force -AllowClobber
    }
    Write-Host "Importing module: $module..." -ForegroundColor Cyan
    Import-Module -Name $module -ErrorAction Stop
}

# Authenticate to Microsoft Graph and retrieve authenticated user
function Authenticate-ToGraph {
    Write-Host
    Write-Host "Authenticating to Microsoft Graph..." -ForegroundColor Cyan

    Connect-MgGraph -ContextScope Process -NoWelcome -ErrorAction Stop

    try {
        # Retrieve the authenticated user's details using Invoke-MgGraphRequest
        $authenticatedUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/me"
        if (-not $authenticatedUser) {
            Write-Host "Failed to retrieve authenticated user information." -ForegroundColor Red
            exit 1
        }
        Write-Host "Authenticated User: $($authenticatedUser.userPrincipalName)" -ForegroundColor Green
        return $authenticatedUser
    } catch {
        Write-Host "Error retrieving user information: $_" -ForegroundColor Red
        exit 1
    }
}

# Function to retrieve PIM roles for the current user
function Get-PIMRolesForUser {
    param (
        [string]$userId
    )
    
    Write-Host
    Write-Host "Retrieving available PIM roles..." -ForegroundColor Cyan
    try {
        # Fetch eligible PIM roles for the user using their UserId
        $pimRoles = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -Filter "principalId eq '$userId'"
        
        if ($pimRoles.Count -eq 0) {
            Write-Host
            Write-Host "No PIM roles available for activation." -ForegroundColor Yellow
            exit
        }
        
        Write-Host
        Write-Host "Retrieved $($pimRoles.Count) PIM role(s)." -ForegroundColor Blue

        $roleList = @()
        foreach ($role in $pimRoles) {
            # Get role definition details using the RoleDefinitionId
            $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $role.RoleDefinitionId
            $roleName = $roleDefinition.DisplayName
            Write-Host "Role Definition Name: $roleName" -ForegroundColor Cyan
            
            # Store role name and ID
            $roleList += [PSCustomObject]@{
                RoleName = $roleName
                RoleId = $role.RoleDefinitionId
            }
        }
        return $roleList
    } catch {
        Write-Host
        Write-Host "Error retrieving PIM roles: $_" -ForegroundColor Red
        exit
    }
}

# Function to display the role selection GUI
function Show-PIMRoleSelectionGUI {
    param (
        [array]$roles
    )

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object Windows.Forms.Form
    $form.Text = "Select a PIM Role to Activate"
    $form.Size = New-Object Drawing.Size(500, 600)
    $form.Font = New-Object Drawing.Font("Arial", 10)

    $groupBox = New-Object Windows.Forms.GroupBox
    $groupBox.Text = "Available Roles"
    $groupBox.Size = New-Object Drawing.Size(450, 320)
    $groupBox.Location = New-Object Drawing.Point(20, 20)

    $radioButtons = @()

    # Dynamically create smaller radio buttons for each role
    $yPosition = 20
    foreach ($role in $roles) {
        $radioButton = New-Object Windows.Forms.RadioButton
        $radioButton.Text = $role.RoleName
        $radioButton.Font = New-Object Drawing.Font("Arial", 10)
        $radioButton.Location = New-Object Drawing.Point(10, $yPosition)
        $radioButton.Size = New-Object Drawing.Size(420, 30)
        $yPosition += 40
        $radioButtons += $radioButton
        $groupBox.Controls.Add($radioButton)
    }

    $justificationLabel = New-Object Windows.Forms.Label
    $justificationLabel.Text = "Enter Justification:"
    $justificationLabel.Location = New-Object Drawing.Point(20, 360)
    $justificationLabel.Size = New-Object Drawing.Size(450, 20)
    $justificationLabel.Font = New-Object Drawing.Font("Arial", 10)

    $justificationBox = New-Object Windows.Forms.TextBox
    $justificationBox.Multiline = $true
    $justificationBox.Size = New-Object Drawing.Size(450, 60)
    $justificationBox.Location = New-Object Drawing.Point(20, 390)
    $justificationBox.Font = New-Object Drawing.Font("Arial", 10)

    $okButton = New-Object Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object Drawing.Point(200, 470)
    $okButton.Font = New-Object Drawing.Font("Arial", 10)

    $okButton.Add_Click({
        $selectedRole = $radioButtons | Where-Object { $_.Checked } | Select-Object -First 1
        $justification = $justificationBox.Text
        if ($null -eq $selectedRole -or [string]::IsNullOrWhiteSpace($justification)) {
            [System.Windows.Forms.MessageBox]::Show("Please select a role and provide a justification.", "Input Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        } else {
            $form.Tag = [PSCustomObject]@{
                RoleName = $selectedRole.Text
                Justification = $justification
            }
            $form.Close()
        }
    })

    $form.Controls.Add($groupBox)
    $form.Controls.Add($justificationLabel)
    $form.Controls.Add($justificationBox)
    $form.Controls.Add($okButton)

    $form.ShowDialog()

    return $form.Tag
}

# Function to retrieve the maximum allowed activation duration for a role
function Get-MaximumAllowedDuration {
    param (
        [string]$roleDefinitionId
    )

    Write-Host
    Write-Host "Retrieving maximum allowed activation duration for the role..." -ForegroundColor Cyan
    try {
        # Fetch the role eligibility schedule for the given role definition ID
        $roleEligibilitySchedule = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "roleDefinitionId eq '$roleDefinitionId'"
        
        if ($roleEligibilitySchedule -and $roleEligibilitySchedule.Expiration) {
            # Extract the maximum allowed duration if it's available
            $maxDuration = $roleEligibilitySchedule.Expiration.Duration
            Write-Host "Maximum allowed duration: $maxDuration" -ForegroundColor Green
            return $maxDuration
        } else {
            # Default to 8 hours if no explicit maximum duration is available
            Write-Host "No explicit duration found, defaulting to 8 hours." -ForegroundColor Yellow
            return "PT8H"
        }
    } catch {
        Write-Host "Error retrieving maximum allowed duration: $_" -ForegroundColor Red
        return "PT8H"  # Fallback to 8 hours if an error occurs
    }
}

# Function to activate PIM role with dynamic duration
function Activate-PIMRole {
    param (
        [string]$selectedRoleName,
        [string]$justification,
        [array]$roles,
        [string]$userId
    )

    $roleToActivate = $roles | Where-Object { $_.RoleName -eq $selectedRoleName }

    if ($roleToActivate -eq $null) {
        Write-Host "Failed to find the selected role for activation." -ForegroundColor Red
        exit
    }

    # Check if the role is already active
    $isRoleActive = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$userId' and roleDefinitionId eq '$($roleToActivate.RoleId)'"
    if ($isRoleActive) {
        Write-Host "The selected role is already active." -ForegroundColor Yellow
        return
    }

    # Get the maximum allowed duration for this role
    $maxDuration = Get-MaximumAllowedDuration -roleDefinitionId $roleToActivate.RoleId

    Write-Host
    Write-Host "Activating PIM role for the allowed duration..." -ForegroundColor Cyan
    try {
        $activationRequest = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -Action "selfActivate" `
            -RoleDefinitionId $roleToActivate.RoleId -PrincipalId $userId -Justification $justification -DirectoryScopeId "/" `
            -ScheduleInfo @{
                StartDateTime = (Get-Date).ToString("o")
                Expiration = @{
                    Type = "AfterDuration"
                    Duration = $maxDuration
                }
            }

        Write-Host "PIM Role Activation request submitted. Please wait..." -ForegroundColor Green

    } catch {
        Write-Host
        Write-Host "Failed to activate the role. Error: $_" -ForegroundColor Red
        exit
    }
    # Confirm role activation after waiting 30 seconds
    Start-Sleep -Seconds 30
    $isRoleActive = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$userId' and roleDefinitionId eq '$($roleToActivate.RoleId)'"
    if ($isRoleActive) {
        Write-Host
        Write-Host "Role is now active." -ForegroundColor Green
    } else {
        Write-Host
        Write-Host "Failed to activate the role." -ForegroundColor Red
        exit
    }
}

# Main script logic
$authenticatedUser = Authenticate-ToGraph
$userId = $authenticatedUser.Id

# Check if the user has eligible roles
$roles = Get-PIMRolesForUser -userId $userId
if ($roles -ne $null) {
    $selection = Show-PIMRoleSelectionGUI -roles $roles
    if ($selection -ne $null) {
        $selectedRoleName = $selection.RoleName
        $justification = $selection.Justification

        Write-Host
        Write-Host "Activating Role: $selectedRoleName" -ForegroundColor DarkCyan
        Write-Host "Justification: $justification" -ForegroundColor DarkCyan

        Activate-PIMRole -selectedRoleName $selectedRoleName -justification $justification -roles $roles -userId $userId
    } else {
        Write-Host
        Write-Host "No role selected or justification entered. Please try again." -ForegroundColor Red
    }
}

Start-Sleep -Seconds 10