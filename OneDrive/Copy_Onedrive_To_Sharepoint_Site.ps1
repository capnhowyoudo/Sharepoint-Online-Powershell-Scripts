<#
.SYNOPSIS
    Copies files and folder structures from a OneDrive for Business source to a SharePoint Online target.

.DESCRIPTION
    This script utilizes the PnP PowerShell module to migrate content between two distinct connections. 
    It identifies all files in a source OneDrive library, recreates the directory nesting at the 
    specified target SharePoint location, and uploads the files while attempting to preserve 
    the 'Created' and 'Modified' metadata timestamps.

.NOTES
    - Requires PnP.PowerShell module installed.
    - Uses Interactive login; ensure the Azure AD App Reg (ClientID) has appropriate 'AllSites.FullControl' or 'AllSites.Write' permissions.
    - Files are temporarily downloaded to the local $Env:TEMP directory during the transfer process.
#>

# Parameters
$SourceSiteUrl = "https://yourtenant-my.sharepoint.com/personal/user_yourtenant_com"
$TargetSiteUrl = "https://yourtenant.sharepoint.com/sites/TargetSite"

$SourceLibraryName = "Documents"
$TargetLibraryName = "Documents"

# Target folder path (example generic structure)
$TargetBaseFolder = "Shared Documents/Department/BackupFolder"

# Replace with your Azure AD App (Client) ID
$ClientID = "00000000-0000-0000-0000-000000000000"

# Connect to source OneDrive
$SourceConn = Connect-PnPOnline `
    -Url $SourceSiteUrl `
    -Interactive `
    -ClientId $ClientID `
    -ReturnConnection

if (-not $SourceConn) {
    throw "Source connection failed."
}

# Connect to target SharePoint
$TargetConn = Connect-PnPOnline `
    -Url $TargetSiteUrl `
    -Interactive `
    -ClientId $ClientID `
    -ReturnConnection

if (-not $TargetConn) {
    throw "Target connection failed."
}

# Get libraries
$SourceLibrary = Get-PnPList `
    -Identity $SourceLibraryName `
    -Connection $SourceConn

$TargetLibrary = Get-PnPList `
    -Identity $TargetLibraryName `
    -Connection $TargetConn

$SourceRootFolder = Get-PnPProperty `
    -ClientObject $SourceLibrary `
    -Property RootFolder `
    -Connection $SourceConn

Write-Host "Target folder: $TargetBaseFolder" -ForegroundColor Cyan

# Confirm base folder exists/access works
try {
    Get-PnPFolder `
        -Url $TargetBaseFolder `
        -Connection $TargetConn `
        -ErrorAction Stop | Out-Null
}
catch {
    throw "Cannot access target folder: $TargetBaseFolder. Check path and permissions. Error: $($_.Exception.Message)"
}

# Get all source items with paging
Write-Host "Reading source files..." -ForegroundColor Cyan

$SourceItems = Get-PnPListItem `
    -List $SourceLibrary `
    -Connection $SourceConn `
    -PageSize 1000 `
    -Fields "FileRef", "FileLeafRef", "FileDirRef", "FSObjType", "Modified", "Created"

$SourceFiles = $SourceItems | Where-Object { $_["FSObjType"] -eq 0 }

$Counter = 1
$TotalFiles = $SourceFiles.Count
$CreatedFolders = @{}

Write-Host "Found $TotalFiles files to copy." -ForegroundColor Cyan

foreach ($File in $SourceFiles) {

    Write-Progress `
        -PercentComplete ($Counter / $TotalFiles * 100) `
        -Activity "Copying Files to BackupFolder" `
        -Status "Copying $($File['FileRef']) ($Counter of $TotalFiles)"

    $SafeFileName = $File["FileLeafRef"]
    $TempFilePath = Join-Path $Env:TEMP $SafeFileName

    $SourceFileRelativeFolder = $File["FileDirRef"].Replace($SourceRootFolder.ServerRelativeUrl, [string]::Empty).TrimStart("/")
    $TargetFolderSiteRelativePath = ($TargetBaseFolder + "/" + $SourceFileRelativeFolder).Replace("\", "/")

    # Create target folder only when needed
    if (-not $CreatedFolders.ContainsKey($TargetFolderSiteRelativePath)) {
        Write-Host "Ensuring folder: $TargetFolderSiteRelativePath" -ForegroundColor DarkGray

        Resolve-PnPFolder `
            -SiteRelativePath $TargetFolderSiteRelativePath `
            -Connection $TargetConn | Out-Null

        $CreatedFolders[$TargetFolderSiteRelativePath] = $true
    }

    try {
        # Download source file
        Get-PnPFile `
            -Url $File["FileRef"] `
            -Connection $SourceConn `
            -AsFile `
            -Path $Env:TEMP `
            -Filename $SafeFileName `
            -Force | Out-Null

        # Upload file
        Add-PnPFile `
            -Path $TempFilePath `
            -Folder $TargetFolderSiteRelativePath `
            -Connection $TargetConn `
            -Values @{
                Modified = $File["Modified"]
                Created  = $File["Created"]
            } | Out-Null

        Write-Host "Copied: $($File['FileRef'])" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed: $($File['FileRef']) - $($_.Exception.Message)"
    }
    finally {
        Remove-Item $TempFilePath -Force -ErrorAction SilentlyContinue
    }

    $Counter++
}

Write-Host "Copy complete." -ForegroundColor Cyan
