<#
.SYNOPSIS
    Copies files and folders from one user's OneDrive for Business to another user's OneDrive for Business.

.DESCRIPTION
    Uses PnP PowerShell to copy all files from a source OneDrive account to a target OneDrive account.
    The script recreates the folder structure under the target folder and attempts to preserve Created
    and Modified timestamps.

.NOTES
    Requires:
    - PnP.PowerShell module
    - Access to both OneDrive sites
    - Azure AD App Client ID with appropriate SharePoint permissions
#>

# =========================
# Parameters
# =========================

$SourceSiteUrl = "https://yourtenant-my.sharepoint.com/personal/sourceuser_yourtenant_com"
$TargetSiteUrl = "https://yourtenant-my.sharepoint.com/personal/targetuser_yourtenant_com"

$SourceLibraryName = "Documents"
$TargetLibraryName = "Documents"

# Folder inside the target user's OneDrive
$TargetBaseFolder = "Documents/BackupFolder"

$ClientID = "00000000-0000-0000-0000-000000000000"

# =========================
# Connect to OneDrive Sites
# =========================

Write-Host "Connecting to source OneDrive..." -ForegroundColor Cyan

$SourceConn = Connect-PnPOnline `
    -Url $SourceSiteUrl `
    -Interactive `
    -ClientId $ClientID `
    -ReturnConnection

if (-not $SourceConn) {
    throw "Source OneDrive connection failed."
}

Write-Host "Connecting to target OneDrive..." -ForegroundColor Cyan

$TargetConn = Connect-PnPOnline `
    -Url $TargetSiteUrl `
    -Interactive `
    -ClientId $ClientID `
    -ReturnConnection

if (-not $TargetConn) {
    throw "Target OneDrive connection failed."
}

# =========================
# Get Libraries
# =========================

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

Write-Host "Target base folder: $TargetBaseFolder" -ForegroundColor Cyan

# =========================
# Ensure Target Base Folder Exists
# =========================

try {
    Resolve-PnPFolder `
        -SiteRelativePath $TargetBaseFolder `
        -Connection $TargetConn | Out-Null
}
catch {
    throw "Cannot create or access target folder: $TargetBaseFolder. Error: $($_.Exception.Message)"
}

# =========================
# Read Source Files
# =========================

Write-Host "Reading source OneDrive files..." -ForegroundColor Cyan

$SourceItems = Get-PnPListItem `
    -List $SourceLibrary `
    -Connection $SourceConn `
    -PageSize 1000 `
    -Fields "FileRef", "FileLeafRef", "FileDirRef", "FSObjType", "Modified", "Created"

$SourceFiles = $SourceItems | Where-Object { $_["FSObjType"] -eq 0 }

$TotalFiles = $SourceFiles.Count
$Counter = 1
$CreatedFolders = @{}

Write-Host "Found $TotalFiles files to copy." -ForegroundColor Cyan

# =========================
# Copy Files
# =========================

foreach ($File in $SourceFiles) {

    if ($TotalFiles -gt 0) {
        Write-Progress `
            -Activity "Copying OneDrive files" `
            -Status "Copying $Counter of $TotalFiles" `
            -PercentComplete (($Counter / $TotalFiles) * 100)
    }

    $SafeFileName = $File["FileLeafRef"]
    $TempFilePath = Join-Path $Env:TEMP $SafeFileName

    $SourceFileRelativeFolder = $File["FileDirRef"].Replace($SourceRootFolder.ServerRelativeUrl, [string]::Empty).TrimStart("/")

    if ([string]::IsNullOrWhiteSpace($SourceFileRelativeFolder)) {
        $TargetFolderSiteRelativePath = $TargetBaseFolder
    }
    else {
        $TargetFolderSiteRelativePath = ($TargetBaseFolder + "/" + $SourceFileRelativeFolder).Replace("\", "/")
    }

    if (-not $CreatedFolders.ContainsKey($TargetFolderSiteRelativePath)) {
        Write-Host "Ensuring folder: $TargetFolderSiteRelativePath" -ForegroundColor DarkGray

        Resolve-PnPFolder `
            -SiteRelativePath $TargetFolderSiteRelativePath `
            -Connection $TargetConn | Out-Null

        $CreatedFolders[$TargetFolderSiteRelativePath] = $true
    }

    try {
        Get-PnPFile `
            -Url $File["FileRef"] `
            -Connection $SourceConn `
            -AsFile `
            -Path $Env:TEMP `
            -Filename $SafeFileName `
            -Force | Out-Null

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

Write-Progress -Activity "Copying OneDrive files" -Completed

Write-Host "OneDrive to OneDrive copy complete." -ForegroundColor Cyan
