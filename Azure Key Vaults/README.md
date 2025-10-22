# Scripts in Azure Key Vaults

## _Manage AKVs
- **Synopsis**
  > Provides a menu-driven launcher for Azure Key Vault management tasks.
- **Description**
  > - Displays a menu of Key Vault actions for the user to choose from.
  > - Invokes the appropriate script based on the selected action.
- **Notes**
  > - Created 2024

---
## AKV Firewall Controls
- **Synopsis**
  > Manages firewall and virtual network (VNet) settings for an Azure Key Vault.
- **Description**
  > - Lists available Key Vaults for selection.
  > - Enables or disables the Key Vault firewall and shows current firewall status.
  > - Views existing VNet assignments.
  > - Adds or removes VNet assignments for the selected Key Vault.
- **Notes**
  > - Created 2024

---
## Audit AKV Access
- **Synopsis**
  > Audits access to an Azure Key Vault using its associated Log Analytics workspace.
- **Description**
  > - Retrieves the associated Log Analytics workspace for the specified Key Vault.
  > - Queries and displays audit logs (time, caller, identity, operation name).
  > - Provides detailed debug information for query execution.
- **Notes**
  > - Created 2024

---
## Backup AKV
- **Synopsis**
  > Backs up secrets and certificates from an Azure Key Vault to a local folder with clear filename extensions.
- **Description**
  > - Retrieves the list of Azure Key Vaults.
  > - Prompts the user to select a Key Vault.
  > - Backs up all items to a local folder:
  > - Secrets saved as *
- **Notes**
  > - Created 2024

---
## Change Ownership of AKV
- **Synopsis**
  > Manages Azure Key Vault ownership and RBAC assignments for specified users.
- **Description**
  > 1. Allow the user to view assigned roles for a user within a specific Azure Key Vault.
  > 2. Allow the user to add owners for the selected Key Vault using the following roles:
  > - Owner
  > - Key Vault Administrator
  > - Key Vault Certificates Officer
  > 3. Allow the user to remove owners for the selected Key Vault using the following roles:
  > - Owner
  > - Key Vault Administrator
  > - Key Vault Certificates Officer
  > - Key Vault Secrets Officer
  > - Key Vault Reader
  > 4. Allow the user to list the RBAC permissions for a specific user on the selected Key Vault.
- **Notes**
  > - Created 2024

---
## Configure Analytics Reporting for AKV
- **Synopsis**
  > Configures Azure Key Vault diagnostic settings to send logs and metrics to a selected Log Analytics Workspace.
- **Description**
  > - Lists available Key Vaults and prompts for selection.
  > - Lists resource groups and prompts for a Log Analytics Workspace resource group.
  > - Prompts for a Log Analytics Workspace within the chosen resource group.
  > - Applies diagnostic settings (logs and metrics) to the selected Key Vault.
  > - Validates that diagnostic settings were successfully applied.
  > - Offers to repeat the process for additional Key Vaults.
- **Notes**
  > - Created 2024

---
## Create AKV
- **Synopsis**
  > Creates an Azure Key Vault with user-specified settings and optional owner assignment.
- **Description**
  > - Prompts for required details (name, location, retention, purge protection, resource group).
  > - Creates the Key Vault.
  > - Optionally assigns additional AKV owners by invoking a companion script.
- **Notes**
  > - Created 2024

---
## Delete AKV
- **Synopsis**
  > Deletes a selected Azure Key Vault after user confirmation.
- **Description**
  > - Retrieves the list of Azure Key Vaults.
  > - Prompts the user to select a Key Vault to delete.
  > - Confirms the deletion before proceeding.
  > - Deletes the selected Key Vault.
- **Notes**
  > - Created 2024

---
## Inventory AKVs
- **Synopsis**
  > Inventories Azure Key Vaults and optionally lists secrets and certificates.
- **Description**
  > - Provides a list of all Key Vaults.
  > - Offers to list secrets.
  > - Offers to list certificates.
  > - Lists secrets and/or certificates in a selected vault or in all vaults based on user input.
- **Notes**
  > - Created 2024

---
## List AKVs
- **Synopsis**
  > Lists all Azure Key Vaults in the current subscription.
- **Description**
  > - Retrieves all Key Vaults in the subscription.
  > - Displays each Key Vault's name and its resource group.
- **Notes**
  > - Created 2024

---
## Recover Deleted AKV
- **Synopsis**
  > Recovers a deleted Azure Key Vault using Azure CLI, with guided selection and validation.
- **Description**
  > - Prompts the user to select a deleted Key Vault to recover.
  > - Uses Azure CLI to perform the recovery operation.
- **Notes**
  > - Created 2024

---
## Restore AKV
- **Synopsis**
  > Restores secrets and certificates from an Azure Key Vault backup to a specified location.
- **Description**
  > - Lists available Key Vaults and prompts the user to select one.
  > - Validates the backup path and supports group (all items) or single-item restoration.
  > - Presents a summary of planned actions for confirmation before proceeding.
  > - Checks required RBAC roles and assigns them if necessary.
- **Notes**
  > - Created 2024
