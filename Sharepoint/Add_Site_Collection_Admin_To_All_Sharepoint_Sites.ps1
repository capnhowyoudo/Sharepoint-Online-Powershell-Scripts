<#
.SYNOPSIS
    Adds a site collection administrator to all SharePoint Online site collections in a tenant.

.DESCRIPTION
    This script connects to a SharePoint Online tenant using PnP PowerShell, retrieves all
    site collections, and adds a specified user as a Site Collection Administrator on each one.

.NOTES
    Requires that a PnP Azure AD App Registration be created and registered, as this is
    needed to supply the Client ID used in Connect-PnPOnline. Without a registered PnP app,
    the ClientID parameter will not be valid and the connection will fail.
#>

#Parameters
$TenantAdminURL = "https://salaudeen-admin.sharepoint.com"
$SiteCollAdmin="user@saludeen.onmicrosoft.com"
$ClientID = "abbaa5e2-27e1-4091-882f-66726a106712"

# Connect to SharePoint Online site
Connect-PnPOnline -Url $TenantAdminURL -Interactive -ClientId $ClientID

#Get All Site collections and Iterate through
$SiteCollections = Get-PnPTenantSite
ForEach($Site in $SiteCollections)
{ 
    #Add Site collection Admin
    Set-PnPTenantSite -Url $Site.Url -Owners $SiteCollAdmin
    Write-host "Added Site Collection Administrator to $($Site.URL)"
}
