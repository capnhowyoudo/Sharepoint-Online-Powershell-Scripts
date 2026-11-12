<#
.SYNOPSIS
    Connects to the SharePoint admin center and retrieves personal OneDrive site information.

.DESCRIPTION
    Connects to the SharePoint Online admin center using PnP PowerShell with
    interactive authentication, then retrieves a count and list of personal
    OneDrive sites along with their URLs and owners. Results are also exported to CSV.

    Requires SharePoint Administrator or Global Administrator rights.
#>

# Variables
$TenantName = "yourtenant"                        # The first part of yourtenant.sharepoint.com
$AdminURL = "https://$TenantName-admin.sharepoint.com/"
$ClientID = "00000000-0000-0000-0000-000000000000"  # Your Entra app registration (client) ID
$ExportPath = "$env:USERPROFILE\Desktop\OneDriveSites.csv"

# Optional: silence the PnP update-check warning
$env:PNPPOWERSHELL_UPDATECHECK = "Off"

# Connect to the SharePoint admin center
Connect-PnPOnline -Url $AdminURL -Interactive -ClientId $ClientID

# Get all personal OneDrive sites
$oneDriveSites = Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'"

# Fallback: if the server-side filter returns nothing, filter client-side
if (-not $oneDriveSites) {
    $oneDriveSites = Get-PnPTenantSite -IncludeOneDriveSites |
        Where-Object { $_.Url -like "*-my.sharepoint.com/personal/*" }
}

# Output
Write-Host "OneDrive sites found: $($oneDriveSites.Count)"
$oneDriveSites | Select-Object Url, Owner | Format-Table -AutoSize

# Export to CSV
$oneDriveSites | Select-Object Url, Owner | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Exported to $ExportPath"
