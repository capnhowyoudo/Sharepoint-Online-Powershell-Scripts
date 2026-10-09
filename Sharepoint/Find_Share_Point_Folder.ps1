<#
.SYNOPSIS
    Finds folders by name in a SharePoint Online site and shows where they are located.

.NOTES
    Requires PnP.PowerShell:  Install-Module PnP.PowerShell -Scope CurrentUser
    Run:  .\Find-SharePointFolder.ps1
#>

# ---------- VARIABLES (edit these) ----------
$SiteURL    = "https://yourtenant.sharepoint.com/sites/YourSite"   # SharePoint site URL
$ClientID   = "00000000-0000-0000-0000-000000000000"               # Entra ID app (client) ID
$FolderName = "FolderNameHere"                                     # Folder name to look for
$ExactMatch = $true     # $true = exact name match, $false = any folder whose name contains the text
# --------------------------------------------

# Connect to SharePoint Online site
Connect-PnPOnline -Url $SiteURL -Interactive -ClientId $ClientID

# Get all document libraries (skip hidden/system ones)
$libraries = Get-PnPList | Where-Object {
    $_.BaseTemplate -eq 101 -and -not $_.Hidden
}

$results = @()

foreach ($lib in $libraries) {
    Write-Host "Searching library: $($lib.Title)" -ForegroundColor Cyan

    # Page through items so large libraries (5000+ items) don't hit the list view threshold
    $items = Get-PnPListItem -List $lib -PageSize 500 -Fields "FileLeafRef","FileRef","FSObjType"

    foreach ($item in $items) {
        # FSObjType 1 = folder
        if ($item["FSObjType"] -eq 1) {
            $name = $item["FileLeafRef"]

            $isMatch = if ($ExactMatch) { $name -eq $FolderName } else { $name -like "*$FolderName*" }

            if ($isMatch) {
                $results += [PSCustomObject]@{
                    Library    = $lib.Title
                    FolderName = $name
                    Path       = $item["FileRef"]
                    FullUrl    = "https://" + ([uri]$SiteURL).Host + $item["FileRef"]
                }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "`nNo folder matching '$FolderName' found in this site." -ForegroundColor Yellow
    Write-Host "It may be in another site, in a recycle bin, or you may lack permission to see it."
} else {
    Write-Host "`nFound $($results.Count) match(es):" -ForegroundColor Green
    $results | Format-Table -AutoSize -Wrap
    $results | Export-Csv -Path ".\FolderSearchResults.csv" -NoTypeInformation
    Write-Host "Results saved to .\FolderSearchResults.csv"
}

# ---------- OPTIONAL: search the whole tenant instead of one site ----------
# Connect to the tenant root, then use SharePoint Search (only returns what you have access to,
# and relies on the search index so very new folders may not show up):
#
# Connect-PnPOnline -Url "https://yourtenant.sharepoint.com" -Interactive -ClientId $ClientID
# Submit-PnPSearchQuery -Query "ContentClass:STS_ListItem_DocumentLibrary IsContainer:true Title:$FolderName" -All |
#     Select-Object Title, Path
#
# ---------- OPTIONAL: check the recycle bin ----------
# Get-PnPRecycleBinItem | Where-Object { $_.Title -like "*$FolderName*" } |
#     Select-Object Title, DirName, DeletedByName, DeletedDate
