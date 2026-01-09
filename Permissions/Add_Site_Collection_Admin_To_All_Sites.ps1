<#
.SYNOPSIS
Adds a specified user as a Site Collection Administrator to all SharePoint Online site collections.

.DESCRIPTION
This script connects to the SharePoint Online tenant admin site using PnP PowerShell
and iterates through all site collections in the tenant. For each site collection,
it assigns the specified user account as a Site Collection Administrator.

The script is useful for ensuring administrative access across all sites for
support, governance, or migration purposes.

.NOTES
- This script must be run by an account with SharePoint Online Administrator
  or Global Administrator permissions.

- A registered PnP PowerShell (Azure AD / Entra ID) application is required.
  The ClientID used must belong to a registered app with the appropriate
  SharePoint permissions granted and consented.

- Parameters such as $TenantAdminURL, $SiteCollAdmin, and $ClientID can be
  modified at the top of the script to match your tenant and target account.

- The script applies changes to ALL site collections returned by Get-PnPTenantSite.
  Use caution when running in production environments.
#>

#Parameters
$TenantAdminURL = "https://yourtenant.sharepoint.com" #Replace with your tenant
$SiteCollAdmin="admin@contoso.com" #Replace with the email address of the account to be assigned Site Collection Administrator access across all sites
$ClientID = "f47ac10b-58cc-4372-a567-0e02b2c3d479" #Your Powershell App ID
   
#Connect to SharePoint Online site
Connect-PnPOnline -Url $TenantAdminURL -Interactive -ClientId $ClientID

#Get All Site collections and Iterate through
$SiteCollections = Get-PnPTenantSite
ForEach($Site in $SiteCollections)
{ 
    #Add Site collection Admin
    Set-PnPTenantSite -Url $Site.Url -Owners $SiteCollAdmin
    Write-host "Added Site Collection Administrator to $($Site.URL)"
}
