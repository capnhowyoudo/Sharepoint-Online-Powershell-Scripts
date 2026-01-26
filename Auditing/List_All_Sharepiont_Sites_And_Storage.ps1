<#
.SYNOPSIS
    Generates a storage usage report for all SharePoint Online site collections using PnP PowerShell.

.DESCRIPTION
    This script connects to the SharePoint Online Admin service using an interactive login with a specific Client ID. 
    It retrieves all tenant sites, calculates the current storage usage and quotas in GB, displays the top 15 
    largest sites in the console, and exports the full results to a CSV file.
#>

# 1. Configuration
$AdminSiteURL = "https://yourtenant-admin.sharepoint.com"
$ClientID = "Your-Azure-App-ID-Here"
$ExportPath = "C:\Temp\PnP_SharePoint_Storage_Report.csv"

# 2. Connect using PnP Interactive
Connect-PnPOnline -Url $AdminSiteURL -Interactive -ClientId $ClientID

# 3. Retrieve all sites with Storage Data
Write-Host "Gathering site collection data..." -ForegroundColor Cyan

# Get-PnPTenantSite retrieves the properties needed for storage reporting
$Sites = Get-PnPTenantSite

$Report = $Sites | ForEach-Object {
    [PSCustomObject]@{
        SiteName       = $_.Title
        Url            = $_.Url
        # PnP returns storage in MB
        StorageUsed_GB = [Math]::Round($_.StorageUsageCurrent / 1024, 2)
        StorageQuota_GB = [Math]::Round($_.StorageQuota / 1024, 2)
        PercentUsed    = if($_.StorageQuota -gt 0) { 
                             [Math]::Round(($_.StorageUsageCurrent / $_.StorageQuota) * 100, 2) 
                         } else { 0 }
        Status         = $_.Status
    }
}

# 4. Export and Display
$Report | Export-Csv -Path $ExportPath -NoTypeInformation
$Report | Sort-Object StorageUsed_GB -Descending | Select-Object -First 15 | Format-Table

Write-Host "Complete! Report saved to $ExportPath" -ForegroundColor Green
