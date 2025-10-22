# Scripts in Miscellaneous

## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Create Symbolic Link.ps1.Name)
- **Synopsis**
  > Creates a directory symbolic link, after validating the target exists and the link path is safe to use.
- **Description**
  > Prompts for an existing target folder and a desired link path, warns if the link path already contains files, and attempts to create a directory symlink (SymbolicLink). Repeats until successful or corrected input is provided. Requires administrative rights or Windows Developer Mode for symlink creation.
- **Notes**
  > - Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Directory Inventory.ps1.Name)
- **Synopsis**
  > Creates a single plain-text “inventory” of all
- **Description**
  > Prompts for a target folder, derives "<FolderName> Inventory
- **Notes**
  > - Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\File Hash Generator.ps1.Name)
- **Synopsis**
  > Computes and displays the SHA-256 hash of a user-specified file.
- **Description**
  > Prompts for a full file path, validates that the file exists, then calculates its SHA-256 hash using Get-FileHash and prints the algorithm, path, and hash; otherwise reports an invalid path.
- **Notes**
  > - Created 2023

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Get Autopilot Hash.ps1.Name)
- **Synopsis**
  > Generates and saves the device’s Windows Autopilot hardware hash to a CSV named after the computer, using Get-WindowsAutopilotInfo.
- **Description**
  > Sets a TLS 1
- **Notes**
  > - Created 2023

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Last Sign-In Report.ps1.Name)
- **Synopsis**
  > Exports an Entra ID user snapshot to a CSV.
- **Description**
  > Authenticates to Microsoft Graph, ensures required modules are present, and prompts for a destination CSV path (creating the folder if needed). 
  >     Enumerates all users and records: UserPrincipalName, last interactive sign-in, last non-interactive sign-in, and whether the account is enabled; 
  >     writes results to CSV with simple progress output. Optimized for PowerShell 7.
- **Notes**
  > - Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\List All Files Modified In Past X Days.ps1.Name)
- **Synopsis**
  > Recursively finds files created or modified within a user-specified number of days starting from a chosen folder.
- **Description**
  > Prompts for a top-level folder and an integer day window, computes a cutoff date, and scans the directory tree. 
  >     Lists matching files (path, last modified, created) when found; otherwise reports that no files matched.
- **Notes**
  > - Created 2025

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\List All Foreground Colors.ps1.Name)
- **Synopsis**
  > Prints sample lines in each standard PowerShell console foreground color for quick visual reference.
- **Description**
  > Clears the console and writes one line per color (Black through Yellow) using -ForegroundColor so users can preview how each color renders in their terminal theme.
- **Notes**
  > - Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\List Microsoft Licenses.ps1.Name)
- **Synopsis**
  > Retrieve and saves all Microsoft 365 subscribed license info
- **Description**
  > Retrieves a full list of all Microsoft 365 subscribed licenses 
  >     Loops through that list to retrieve detailed information on each one 
  >     Saves the first list as Microsoft_License_List
- **Notes**
  > Created 2025

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\PIM Role Assignment.ps1.Name)
- **Synopsis**
  > GUI-assisted activation of an eligible Entra ID (Azure AD) PIM role with justification for the maximum allowed duration.
- **Description**
  > The script authenticates to Microsoft Graph, discovers the signed-in user’s eligible PIM roles, and displays a simple Windows Forms UI to: 
  >       • Select a role and enter a justification 
  >       • Submit a self-activate request (skips if the role is already active) 
  >       • Use the tenant’s maximum permitted activation duration for that role 
  >     On success, it confirms activation.
- **Notes**
  > - Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\PS7 Prep.ps1.Name)
- **Synopsis**
  > Preps a technician workstation for PowerShell 7 scripting: verifies prerequisites, configures package sources, installs core modules/tools, and updates the environment.
- **Description**
  > The script: 
  >       • Ensures it’s running in PowerShell 7 and as Administrator. 
  >       • Sets TLS 1
- **Notes**
  > - Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Script Inventory.ps1.Name)
- **Synopsis**
  > or
- **Description**
  > .
- **Notes**
  > Created 2025

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Show Hostname on Lock Screen.ps1.Name)
- **Synopsis**
  > Create and set a lock screen image displaying the computer's hostname
- **Description**
  > Looks up the computer's hostname 
  >     Creates a JPG image with black background and the hostname centered on it  
  >     Pokes the registry so the computer uses the new file as the default lock screen
- **Notes**
  > This script requires PowerShell 7 and admin privileges 
  >     Created 2024

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Update All PowerShell Modules.ps1.Name)
- **Synopsis**
  > Updates all installed modules for both Windows PowerShell 5 and PowerShell 7, including a PS5 bootstrap if PackageManagement/PowerShellGet are missing, then prints a single consolidated update summary.
- **Description**
  > The script: 
  >       • Verifies elevation and locates pwsh
- **Notes**
  > - Created 2025

---\n## $(C:\Users\joe\OneDrive - Buena Vista University\GitHub\PowerShell\Miscellaneous\Use Self-Signed Cert to Sign Application.ps1.Name)
- **Synopsis**
  > Creates a self-signed code-signing certificate, stores its artifacts in Azure Key Vault, and signs a specified application.
- **Description**
  > Runs in PowerShell 7 with local admin rights. The script: 
  >       • Validates the target executable path and prompts for an application name. 
  >       • Ensures signtool
- **Notes**
  > - Created 2024

---\n
