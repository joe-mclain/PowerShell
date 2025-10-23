# Scripts in Miscellaneous

## Create Symbolic Link
- **Synopsis**
 > Creates a directory symbolic link, after validating the target exists and the link path is safe to use.
- **Description**
 > Prompts for an existing target folder and a desired link path, warns if the link path already contains files, and attempts to create a directory symlink (SymbolicLink). Repeats until successful or corrected input is provided. Requires administrative rights or Windows Developer Mode for symlink creation.
- **Notes**
 > - Created 2024.09.02 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.09.05 at 1315 by Joe McLain (joe@bvu.edu)

---
## Directory Inventory
- **Synopsis**
 > Creates a single plain-text  inventory  of all .ps1 files in a chosen directory by concatenating each filename and its contents.
- **Description**
 > Prompts for a target folder, derives "<FolderName> Inventory.txt" as the output file, and collects all .ps1 files (non-recursive).
 > For each script it writes the file name, then the full file contents, separated by blank lines, producing one consolidated reference file.
- **Notes**
 > - Created 2024.09.17 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.09.17 at 1734 by Joe McLain (joe@bvu.edu)

---
## File Hash Generator
- **Synopsis**
 > Computes and displays the SHA-256 hash of a user-specified file.
- **Description**
 > Prompts for a full file path, validates that the file exists, then calculates its SHA-256 hash using Get-FileHash and prints the algorithm, path, and hash; otherwise reports an invalid path.
- **Notes**
 > - Created 2023.08.19 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.02.21 at 0914 by Joe McLain (joe@bvu.edu)

---
## Get Autopilot Hash
- **Synopsis**
 > Generates and saves the device s Windows Autopilot hardware hash to a CSV named after the computer, using Get-WindowsAutopilotInfo.
- **Description**
 > Sets a TLS 1.2 session, uses the script s folder as the working directory, and ensures it exists. Temporarily allows script execution for the process, adds the standard Scripts path to PATH, installs the Get-WindowsAutopilotInfo tool if needed, then runs it to create "<COMPUTERNAME>_APHash.csv" in the script directory. Emits clear success/error messages.
- **Notes**
 > - Created 2023.08.24 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.06.13 at 1413 by Joe McLain (joe@bvu.edu)

---
## Last Sign-In Report
- **Synopsis**
 > Exports an Entra ID user snapshot to a CSV.
- **Description**
 > Authenticates to Microsoft Graph, ensures required modules are present, and prompts for a destination CSV path (creating the folder if needed).
 > Enumerates all users and records: UserPrincipalName, last interactive sign-in, last non-interactive sign-in, and whether the account is enabled;
 > writes results to CSV with simple progress output. Optimized for PowerShell 7.
- **Notes**
 > - Created 2024.09.26 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.09.27 at 1017 by Joe McLain (joe@bvu.edu)

---
## List All Files Modified In Past X Days
- **Synopsis**
 > Recursively finds files created or modified within a user-specified number of days starting from a chosen folder.
- **Description**
 > Prompts for a top-level folder and an integer day window, computes a cutoff date, and scans the directory tree.
 > Lists matching files (path, last modified, created) when found; otherwise reports that no files matched.
- **Notes**
 > - Created 2025.07.25 by Joe McLain (joe@bvu.edu)
 > - Last modified 2025.07.25 at 0000 by Joe McLain (joe@bvu.edu)

---
## List All Foreground Colors
- **Synopsis**
 > Prints sample lines in each standard PowerShell console foreground color for quick visual reference.
- **Description**
 > Clears the console and writes one line per color (Black through Yellow) using -ForegroundColor so users can preview how each color renders in their terminal theme.
- **Notes**
 > - Created 2024.09.17 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.09.17 at 1005 by Joe McLain (joe@bvu.edu)

---
## List Microsoft Licenses
- **Synopsis**
 > Retrieve and saves all Microsoft 365 subscribed license info
- **Description**
 > Retrieves a full list of all Microsoft 365 subscribed licenses
 > Loops through that list to retrieve detailed information on each one
 > Saves the first list as Microsoft_License_List.txt
 > Saves the first list as Microsoft_License_Detail.txt
- **Notes**
 > Created 2025.09.23 by Joe McLain (joe@bvu.edu)
 > Updated on 2025.10.20 at 1613 by Joe McLain (joe@bvu.edu)

---
## PIM Role Assignment
- **Synopsis**
 > GUI-assisted activation of an eligible Entra ID (Azure AD) PIM role with justification for the maximum allowed duration.
- **Description**
 > The script authenticates to Microsoft Graph, discovers the signed-in user s eligible PIM roles, and displays a simple Windows Forms UI to:
 > Select a role and enter a justification
 > Submit a self-activate request (skips if the role is already active)
 > Use the tenant s maximum permitted activation duration for that role
 > On success, it confirms activation.
- **Notes**
 > - Created 2024.09.25 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.10.03 at 1131 by Joe McLain (joe@bvu.edu)

---
## PS7 Prep
- **Synopsis**
 > Preps a technician workstation for PowerShell 7 scripting: verifies prerequisites, configures package sources, installs core modules/tools, and updates the environment.
- **Description**
 > The script:
 > Ensures it s running in PowerShell 7 and as Administrator.
 > Sets TLS 1.2 and registers PowerShell Gallery as a trusted repository.
 > Refreshes PackageManagement/PowerShellGet (in a separate elevated session).
 > Installs core modules (Microsoft.Graph, Az) and updates all installed modules.
 > Creates the user PowerShell profile directory if missing.
 > Installs Git silently if not present; initiates VS Code install via Microsoft Store if not present.
 > Prints clear status for each step and a completion message.
- **Notes**
 > - Created 2024.09.16 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.11.19 at 1631 by Joe McLain (joe@bvu.edu)

---
## Script Inventory
- **Synopsis**
 > Inventory PowerShell scripts under the current folder, extracting SYNOPSIS, DESCRIPTION, and NOTES metadata.
- **Description**
 > Starting at the folder from which it is run, this script recurses downward to find all *.ps1 files.
 > For each file, it inspects the comment-based help blocks and, when present, extracts:
 > - .SYNOPSIS (multi-line, until the next dotted section)
 > - .DESCRIPTION (multi-line, until the next dotted section)
 > - .NOTES lines for:
 > Created YYYY.MM.DD by Name (email)
 > Updated/Last updated [on] YYYY.MM.DD [at HHMM|HH:MM] by Name (email)
 > It writes one XLSX in the working directory with two worksheets:
 > - Inventory (columns: File Path, File Name, Synopsis, Description, Creation Date, Creator Name, Modification Date, Modification Time, Modifier Name)
 > - Needing Updates (columns: File Path, File Name)
 > Needing updates  are files missing either .SYNOPSIS or .DESCRIPTION.
- **Notes**
 > Created 2025.09.23 by Joe McLain (joe@bvu.edu)
 > Updated on 2025.09.24 at 0904 by Joe McLain (joe@bvu.edu)

---
## Show Hostname on Lock Screen
- **Synopsis**
 > Create and set a lock screen image displaying the computer's hostname
- **Description**
 > Looks up the computer's hostname
 > Creates a JPG image with black background and the hostname centered on it
 > Pokes the registry so the computer uses the new file as the default lock screen
- **Notes**
 > This script requires PowerShell 7 and admin privileges
 > Created 2024.07.25 by Joe McLain (joe@bvu.edu)
 > Updated on 2025.10.20 at 1210 by Joe McLain (joe@bvu.edu)

---
## Update All PowerShell Modules
- **Synopsis**
 > Updates all installed modules for both Windows PowerShell 5 and PowerShell 7, including a PS5 bootstrap if PackageManagement/PowerShellGet are missing, then prints a single consolidated update summary.
- **Description**
 > The script:
 > Verifies elevation and locates pwsh.exe for PS7.
 > Bootstraps Windows PowerShell 5 by ensuring PackageManagement/PowerShellGet are present (with a fallback that downloads from PowerShell Gallery if needed) and normalizes PSModulePath.
 > Runs module updates separately in PS5 and PS7 hosts, checking each installed module against the gallery and updating when newer versions exist.
 > Collects results from both hosts and outputs a concise table of modules that changed (old   new), or states that no updates were required.
- **Notes**
 > - Created 2025.07.30 by Joe McLain (joe@bvu.edu)
 > - Last modified 2025.07.30 at 0930 by Joe McLain (joe@bvu.edu)

---
## Use Self-Signed Cert to Sign Application
- **Synopsis**
 > Creates a self-signed code-signing certificate, stores its artifacts in Azure Key Vault, and signs a specified application.
- **Description**
 > Runs in PowerShell 7 with local admin rights. The script:
 > Validates the target executable path and prompts for an application name.
 > Ensures signtool.exe is available (installs the Windows SDK via winget if needed).
 > Authenticates to Azure, lets you choose a Key Vault, and generates a strong password.
 > Creates a self-signed code-signing certificate, exports .cer and .pfx, and signs the app.
 > Stores the password and certificate artifacts (.cer/.pfx) in the selected Key Vault.
- **Notes**
 > - Created 2024.08.07 by Joe McLain (joe@bvu.edu)
 > - Last modified 2024.09.24 at 1123 by Joe McLain (joe@bvu.edu)
