# Scripts in Purview

## Create eDiscovery Case
- **Synopsis**
  > Creates a Purview Premium eDiscovery (Advanced) case, places custodians on indefinite hold (Exchange + OneDrive), and runs an initial content search using a shared KQL filter.
- **Description**
  > This script:
  >       ? Prompts for case metadata, custodial UPNs, and optional keywords.
  >       ? Builds a single KQL query (participants + keywords) used for both hold scoping and search.
  >       ? Applies an indefinite custodial hold to custodians? mailboxes (email, calendar, contacts, tasks, Teams 1:1/group chats, archives/Recoverable Items) and personal OneDrive sites.
  >       ? Creates and starts a Compliance Search inside the case with the same KQL.
  >       ? Outputs a concise summary of held locations and search start status.
- **Notes**
  > - Created 2025
