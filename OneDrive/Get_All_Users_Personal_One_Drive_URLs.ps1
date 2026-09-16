<#
.SYNOPSIS
    Connects to a SharePoint Online site and retrieves personal OneDrive site information.

.DESCRIPTION
    This script connects to a SharePoint Online site using PnP PowerShell with
    interactive authentication, then retrieves a count and list of personal
    OneDrive sites along with their URLs and owners.
#>

# Variables
$SiteURL = "https://salaudeen.sharepoint.com/sites/Retail"
$ClientID = "abbaa5e2-27e1-4091-882f-66726a106712"

# Connect to SharePoint Online site
Connect-PnPOnline -Url $SiteURL -Interactive -ClientId $ClientID

$oneDriveSites.Count
$oneDriveSites | Select-Object Url, Owner
