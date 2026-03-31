<#
.SYNOPSIS
Generates a SharePoint Online permissions report using PnP PowerShell,
optionally limited to one specific list/library across the site.

.EXAMPLE
# Only scan one list in the root site
Generate-PnPSitePermissionRpt `
    -SiteURL "https://yourtenant.sharepoint.com/sites/YourSite" `
    -ReportFile "C:\Temp\YourReport.csv" `
    -TargetListName "Shared Documents" `
    -ScanItemLevel

.EXAMPLE
# Scan one list across the whole site collection recursively
Generate-PnPSitePermissionRpt `
    -SiteURL "https://yourtenant.sharepoint.com/sites/YourSite" `
    -ReportFile "C:\Temp\YourReport.csv" `
    -TargetListName "Policies" `
    -Recursive `
    -ScanItemLevel
#>

Function Get-PnPPermissions([Microsoft.SharePoint.Client.SecurableObject]$Object)
{
    Switch($Object.TypedObject.ToString())
    {
        "Microsoft.SharePoint.Client.Web" {
            $ObjectType  = "Site"
            $ObjectURL   = $Object.Url
            $ObjectTitle = $Object.Title
        }
        "Microsoft.SharePoint.Client.ListItem" {
            if($Object.FileSystemObjectType -eq "Folder")
            {
                $ObjectType  = "Folder"
                $Folder      = Get-PnPProperty -ClientObject $Object -Property Folder
                $ObjectTitle = $Object.Folder.Name
                $ObjectURL   = ("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $Object.Folder.ServerRelativeUrl)
            }
            else
            {
                Get-PnPProperty -ClientObject $Object -Property File, ParentList
                if($Object.File.Name)
                {
                    $ObjectType  = "File"
                    $ObjectTitle = $Object.File.Name
                    $ObjectURL   = ("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $Object.File.ServerRelativeUrl)
                }
                else
                {
                    $ObjectType  = "List Item"
                    $ObjectTitle = $Object["Title"]
                    $DefaultDisplayFormUrl = Get-PnPProperty -ClientObject $Object.ParentList -Property DefaultDisplayFormUrl
                    $ObjectURL = ("{0}{1}?ID={2}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $DefaultDisplayFormUrl, $Object.ID)
                }
            }
        }
        Default {
            $ObjectType  = "List or Library"
            $ObjectTitle = $Object.Title
            $RootFolder  = Get-PnPProperty -ClientObject $Object -Property RootFolder
            $ObjectURL   = ("{0}{1}" -f $Web.Url.Replace($Web.ServerRelativeUrl,''), $RootFolder.ServerRelativeUrl)
        }
    }

    Get-PnPProperty -ClientObject $Object -Property HasUniqueRoleAssignments, RoleAssignments
    $HasUniquePermissions = $Object.HasUniqueRoleAssignments
    $PermissionCollection = @()

    foreach($RoleAssignment in $Object.RoleAssignments)
    {
        Get-PnPProperty -ClientObject $RoleAssignment -Property RoleDefinitionBindings, Member

        $PermissionType   = $RoleAssignment.Member.PrincipalType
        $PermissionLevels = $RoleAssignment.RoleDefinitionBindings | Select-Object -ExpandProperty Name
        $PermissionLevels = ($PermissionLevels | Where-Object { $_ -ne "Limited Access" }) -join ","

        if([string]::IsNullOrWhiteSpace($PermissionLevels)) { continue }

        if($PermissionType -eq "SharePointGroup")
        {
            $GroupMembers = Get-PnPGroupMember -Identity $RoleAssignment.Member.LoginName
            if($GroupMembers.Count -eq 0) { continue }

            $GroupUsers = ($GroupMembers | Select-Object -ExpandProperty Title) -join ","

            $Permissions = [PSCustomObject]@{
                Object               = $ObjectType
                Title                = $ObjectTitle
                URL                  = $ObjectURL
                HasUniquePermissions = $HasUniquePermissions
                Users                = $GroupUsers
                Type                 = $PermissionType
                Permissions          = $PermissionLevels
                GrantedThrough       = "SharePoint Group: $($RoleAssignment.Member.LoginName)"
            }
            $PermissionCollection += $Permissions
        }
        else
        {
            $Permissions = [PSCustomObject]@{
                Object               = $ObjectType
                Title                = $ObjectTitle
                URL                  = $ObjectURL
                HasUniquePermissions = $HasUniquePermissions
                Users                = $RoleAssignment.Member.Title
                Type                 = $PermissionType
                Permissions          = $PermissionLevels
                GrantedThrough       = "Direct Permissions"
            }
            $PermissionCollection += $Permissions
        }
    }

    $PermissionCollection | Export-Csv $ReportFile -NoTypeInformation -Append
}

Function Generate-PnPSitePermissionRpt()
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)] [string] $SiteURL,
        [Parameter(Mandatory = $false)] [string] $ReportFile,
        [Parameter(Mandatory = $false)] [switch] $Recursive,
        [Parameter(Mandatory = $false)] [switch] $ScanItemLevel,
        [Parameter(Mandatory = $false)] [switch] $IncludeInheritedPermissions,

        # NEW: only scan this list/library title
        [Parameter(Mandatory = $false)] [string] $TargetListName
    )

    try {
        Connect-PnPOnline -Url $SiteURL -Interactive -ClientId $ClientID
        $script:Web = Get-PnPWeb

        Write-Host -ForegroundColor Yellow "Getting Site Collection Administrators..."
        $SiteAdmins = Get-PnPSiteCollectionAdmin
        $SiteCollectionAdmins = ($SiteAdmins | Select-Object -ExpandProperty Title) -join ","

        $Permissions = [PSCustomObject]@{
            Object               = "Site Collection"
            Title                = $Web.Title
            URL                  = $Web.Url
            HasUniquePermissions = "TRUE"
            Users                = $SiteCollectionAdmins
            Type                 = "Site Collection Administrators"
            Permissions          = "Site Owner"
            GrantedThrough       = "Direct Permissions"
        }

        $Permissions | Export-Csv $ReportFile -NoTypeInformation

        Function Get-PnPListItemsPermission([Microsoft.SharePoint.Client.List]$List)
        {
            Write-Host -ForegroundColor Yellow "`t`tGetting Permissions of List Items in the List: $($List.Title)"
            $ListItems = Get-PnPListItem -List $List -PageSize 500
            $ItemCounter = 0

            foreach($ListItem in $ListItems)
            {
                if($IncludeInheritedPermissions)
                {
                    Get-PnPPermissions -Object $ListItem
                }
                else
                {
                    $HasUniquePermissions = Get-PnPProperty -ClientObject $ListItem -Property HasUniqueRoleAssignments
                    if($HasUniquePermissions -eq $true)
                    {
                        Get-PnPPermissions -Object $ListItem
                    }
                }

                $ItemCounter++
                Write-Progress -PercentComplete (($ItemCounter / [Math]::Max($List.ItemCount,1)) * 100) `
                    -Activity "Processing Items $ItemCounter of $($List.ItemCount)" `
                    -Status "Searching Permissions in '$($List.Title)'"
            }
        }

        Function Get-PnPListPermission([Microsoft.SharePoint.Client.Web]$Web)
        {
            $Lists = Get-PnPProperty -ClientObject $Web -Property Lists

            $ExcludedLists = @(
                "Access Requests","App Packages","appdata","appfiles","Apps in Testing","Cache Profiles",
                "Composed Looks","Content and Structure Reports","Content type publishing error log","Converted Forms",
                "Device Channels","Form Templates","fpdatasources","Get started with Apps for Office and SharePoint",
                "List Template Gallery","Long Running Operation Status","Maintenance Log Library","Images",
                "site collection images","Master Docs","Master Page Gallery","MicroFeed","NintexFormXml",
                "Quick Deploy Items","Relationships List","Reusable Content","Reporting Metadata",
                "Reporting Templates","Search Config List","Site Assets","Preservation Hold Library",
                "Site Pages","Solution Gallery","Style Library","Suggested Content Browser Locations",
                "Theme Gallery","TaxonomyHiddenList","User Information List","Web Part Gallery","wfpub",
                "wfsvc","Workflow History","Workflow Tasks","Pages"
            )

            $VisibleLists = $Lists | Where-Object {
                $_.Hidden -eq $false -and $ExcludedLists -notcontains $_.Title
            }

            # NEW: only keep the requested list
            if(-not [string]::IsNullOrWhiteSpace($TargetListName))
            {
                $VisibleLists = $VisibleLists | Where-Object { $_.Title -eq $TargetListName }
            }

            $Counter = 0
            foreach($List in $VisibleLists)
            {
                $Counter++
                Write-Progress -PercentComplete (($Counter / [Math]::Max($VisibleLists.Count,1)) * 100) `
                    -Activity "Exporting Permissions from List '$($List.Title)' in $($Web.Url)" `
                    -Status "Processing Lists $Counter of $($VisibleLists.Count)"

                if($ScanItemLevel)
                {
                    Get-PnPListItemsPermission -List $List
                }

                if($IncludeInheritedPermissions)
                {
                    Get-PnPPermissions -Object $List
                }
                else
                {
                    $HasUniquePermissions = Get-PnPProperty -ClientObject $List -Property HasUniqueRoleAssignments
                    if($HasUniquePermissions -eq $true)
                    {
                        Get-PnPPermissions -Object $List
                    }
                }
            }

            if(-not [string]::IsNullOrWhiteSpace($TargetListName) -and $VisibleLists.Count -eq 0)
            {
                Write-Host -ForegroundColor DarkYellow "List '$TargetListName' not found in web: $($Web.Url)"
            }
        }

        Function Get-PnPWebPermission([Microsoft.SharePoint.Client.Web]$Web)
        {
            Write-Host -ForegroundColor Yellow "Getting Permissions of the Web: $($Web.Url)..."

            # Keep web-level reporting
            if($IncludeInheritedPermissions)
            {
                Get-PnPPermissions -Object $Web
            }
            else
            {
                $HasUniquePermissions = Get-PnPProperty -ClientObject $Web -Property HasUniqueRoleAssignments
                if($HasUniquePermissions -eq $true)
                {
                    Get-PnPPermissions -Object $Web
                }
            }

            Write-Host -ForegroundColor Yellow "`tGetting Permissions of Lists and Libraries..."
            Get-PnPListPermission -Web $Web

            if($Recursive)
            {
                $Subwebs = Get-PnPProperty -ClientObject $Web -Property Webs
                foreach($Subweb in $Subwebs)
                {
                    # Recurse regardless when targeting a list,
                    # otherwise you may skip subwebs that inherit permissions
                    if(-not [string]::IsNullOrWhiteSpace($TargetListName))
                    {
                        Get-PnPWebPermission -Web $Subweb
                    }
                    elseif($IncludeInheritedPermissions)
                    {
                        Get-PnPWebPermission -Web $Subweb
                    }
                    else
                    {
                        $HasUniquePermissions = Get-PnPProperty -ClientObject $Subweb -Property HasUniqueRoleAssignments
                        if($HasUniquePermissions -eq $true)
                        {
                            Get-PnPWebPermission -Web $Subweb
                        }
                    }
                }
            }
        }

        Get-PnPWebPermission -Web $Web
        Write-Host -ForegroundColor Green "`n*** Site Permission Report Generated Successfully! ***"
    }
    catch {
        Write-Host -ForegroundColor Red "Error Generating Site Permission Report! $($_.Exception.Message)"
    }
}

#region ***Parameters***
$ClientID   = "f47ac10b-58cc-4372-a567-0e02b2c3d479"
$SiteURL    = "https://yourtenant.sharepoint.com/sites/YourSite"
$ReportFile = "C:\Temp\YourReport.csv"

# NEW: set the exact list/library title here
$TargetListName = "Shared Documents"
#endregion

# Examples
# Root site only, one list
# Generate-PnPSitePermissionRpt -SiteURL $SiteURL -ReportFile $ReportFile -TargetListName $TargetListName -ScanItemLevel

# Whole site collection, one list across all sub-sites
Generate-PnPSitePermissionRpt `
    -SiteURL $SiteURL `
    -ReportFile $ReportFile `
    -TargetListName $TargetListName `
    -Recursive `
    -ScanItemLevel

# Whole site collection, one list, include inherited permissions too
# Generate-PnPSitePermissionRpt -SiteURL $SiteURL -ReportFile $ReportFile -TargetListName $TargetListName -Recursive -ScanItemLevel -IncludeInheritedPermissions
