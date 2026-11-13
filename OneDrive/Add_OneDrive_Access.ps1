<#
.SYNOPSIS
    Grants (or removes) an account's access to multiple users' OneDrive for Business sites.

.DESCRIPTION
    Reads a list of user UPNs from a CSV, finds each user's OneDrive URL, and adds the chosen
    account as a Site Collection Administrator on it (full access to the files). Use -Remove to
    take the access away again. Results are written to a CSV log.

    CSV format (header required):
        UserPrincipalName
        user1@yourtenant.com
        user2@yourtenant.com

.NOTES
    Requires:
    - PnP.PowerShell 2.x+ (PowerShell 7.2+)
    - SharePoint Administrator (or Global Administrator) to run it
    - An Entra ID app registration (ClientId) with delegated SharePoint permissions,
      e.g. AllSites.FullControl, with admin consent granted

.EXAMPLE
    .\Add_OneDrive_Access.ps1 -TenantName yourtenant -ClientId 0000... -CsvPath .\users.csv -GrantTo admin@yourtenant.com

.EXAMPLE
    .\Add_OneDrive_Access.ps1 -TenantName yourtenant -ClientId 0000... -CsvPath .\users.csv -GrantTo admin@yourtenant.com -Remove

.EXAMPLE
    # Preview only
    .\Add_OneDrive_Access.ps1 -TenantName yourtenant -ClientId 0000... -CsvPath .\users.csv -GrantTo admin@yourtenant.com -WhatIf
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory)] [string] $TenantName,      # "contoso", "contoso.onmicrosoft.com" or a full domain like "contoso.org"
    [Parameter(Mandatory)] [string] $ClientId,        # Entra ID app registration client ID
    [Parameter(Mandatory)] [string] $CsvPath,         # CSV with a UserPrincipalName column
    [Parameter(Mandatory)] [string] $GrantTo,         # UPN of the account that should get access
    [switch] $Remove,                                 # Remove the access instead of adding it
    [string] $LogPath = ".\OneDriveAccess-Log-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
)

$ErrorActionPreference = "Stop"

function Resolve-SharePointTenantName {
    param([Parameter(Mandatory)] [string] $Name)

    $Name = $Name.Trim().ToLower()

    # Already a short name (no dots), e.g. "contoso"
    if ($Name -notmatch "\.") { return $Name }

    # Already an onmicrosoft.com domain, e.g. "contoso.onmicrosoft.com"
    if ($Name -match "^([^\.]+)\.onmicrosoft\.com$") { return $Matches[1] }

    # Full custom domain, e.g. "contoso.org": ask Microsoft which domains belong to this tenant
    # and pick the <name>.onmicrosoft.com one. No sign-in is needed for this lookup.
    try {
        $Body = @"
<soap:Envelope xmlns:exm="http://schemas.microsoft.com/exchange/services/2006/messages" xmlns:ext="http://schemas.microsoft.com/exchange/services/2006/types" xmlns:a="http://www.w3.org/2005/08/addressing" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <soap:Header>
    <a:Action soap:mustUnderstand="1">http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation</a:Action>
    <a:To soap:mustUnderstand="1">https://autodiscover-s.outlook.com/autodiscover/autodiscover.svc</a:To>
    <a:ReplyTo><a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address></a:ReplyTo>
  </soap:Header>
  <soap:Body>
    <GetFederationInformationRequestMessage xmlns="http://schemas.microsoft.com/exchange/2010/Autodiscover">
      <Request><Domain>$Name</Domain></Request>
    </GetFederationInformationRequestMessage>
  </soap:Body>
</soap:Envelope>
"@
        $Headers = @{
            "Content-Type" = "text/xml; charset=utf-8"
            "SOAPAction"   = '"http://schemas.microsoft.com/exchange/2010/Autodiscover/Autodiscover/GetFederationInformation"'
            "User-Agent"   = "AutodiscoverClient"
        }
        $Response = Invoke-RestMethod -Method Post -Uri "https://autodiscover-s.outlook.com/autodiscover/autodiscover.svc" `
            -Headers $Headers -Body $Body -ErrorAction Stop

        $Domains = @($Response.Envelope.Body.GetFederationInformationResponseMessage.Response.Domains.Domain)
        $Initial = $Domains | Where-Object { $_ -match "\.onmicrosoft\.com$" -and $_ -notmatch "\.mail\.onmicrosoft\.com$" } | Select-Object -First 1

        if ($Initial) {
            return ($Initial -replace "\.onmicrosoft\.com$", "")
        }
    }
    catch {
        Write-Warning "Could not look up the tenant name for '$Name': $($_.Exception.Message)"
    }

    # Last resort: use the first part of the domain and tell the user
    $Guess = $Name.Split(".")[0]
    Write-Warning "Falling back to '$Guess' as the SharePoint tenant name. If the connection fails, pass the short name (the part before .onmicrosoft.com)."
    return $Guess
}

$TenantShortName = Resolve-SharePointTenantName -Name $TenantName
Write-Host "Using SharePoint tenant name: $TenantShortName" -ForegroundColor Cyan

$AdminUrl = "https://$TenantShortName-admin.sharepoint.com"
$MySiteHost = "https://$TenantShortName-my.sharepoint.com"

if (-not (Test-Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

$Users = @(Import-Csv -Path $CsvPath)
if ($Users.Count -eq 0 -or -not ($Users[0].PSObject.Properties.Name -contains "UserPrincipalName")) {
    throw "CSV must contain a 'UserPrincipalName' column and at least one row."
}

Write-Host "Connecting to SharePoint admin center..." -ForegroundColor Cyan
Connect-PnPOnline -Url $AdminUrl -Interactive -ClientId $ClientId

$Results = New-Object System.Collections.Generic.List[object]
$Total = $Users.Count
$Counter = 0

foreach ($User in $Users) {
    $Counter++
    $Upn = $User.UserPrincipalName.Trim()

    if ([string]::IsNullOrWhiteSpace($Upn)) { continue }

    Write-Progress -Activity "Updating OneDrive access" -Status "$Counter of $Total : $Upn" `
        -PercentComplete (($Counter / $Total) * 100)

    $Status = "Success"
    $Detail = ""
    $OneDriveUrl = ""

    try {
        # Look up the OneDrive URL from the user profile; fall back to the standard URL pattern
        try {
            $Profile = Get-PnPUserProfileProperty -Account $Upn
            $OneDriveUrl = $Profile.PersonalUrl
        }
        catch { }

        if ([string]::IsNullOrWhiteSpace($OneDriveUrl)) {
            $Suffix = $Upn -replace "[\.@]", "_"
            $OneDriveUrl = "$MySiteHost/personal/$Suffix"
        }
        $OneDriveUrl = $OneDriveUrl.TrimEnd("/")

        if ($Remove) {
            if ($PSCmdlet.ShouldProcess($OneDriveUrl, "Remove $GrantTo as site collection admin")) {
                # Removing an admin needs a connection to the site itself
                Connect-PnPOnline -Url $OneDriveUrl -Interactive -ClientId $ClientId
                Remove-PnPSiteCollectionAdmin -Owners $GrantTo
                Connect-PnPOnline -Url $AdminUrl -Interactive -ClientId $ClientId
                $Detail = "Removed $GrantTo"
            }
            else { $Detail = "WhatIf: would remove $GrantTo" }
        }
        else {
            if ($PSCmdlet.ShouldProcess($OneDriveUrl, "Add $GrantTo as site collection admin")) {
                Set-PnPTenantSite -Identity $OneDriveUrl -Owners $GrantTo
                $Detail = "Added $GrantTo"
            }
            else { $Detail = "WhatIf: would add $GrantTo" }
        }

        Write-Host "[OK]    $Upn -> $OneDriveUrl" -ForegroundColor Green
    }
    catch {
        $Status = "Failed"
        $Detail = $_.Exception.Message
        Write-Warning "[FAIL]  $Upn : $Detail"

        # Make sure we are back on the admin connection after a failed removal attempt
        try { Connect-PnPOnline -Url $AdminUrl -Interactive -ClientId $ClientId } catch { }
    }

    $Results.Add([pscustomobject]@{
        UserPrincipalName = $Upn
        OneDriveUrl       = $OneDriveUrl
        Action            = $(if ($Remove) { "Remove" } else { "Add" })
        GrantedTo         = $GrantTo
        Status            = $Status
        Detail            = $Detail
        Timestamp         = Get-Date
    })
}

Write-Progress -Activity "Updating OneDrive access" -Completed

$Results | Export-Csv -Path $LogPath -NoTypeInformation -Encoding UTF8

$Ok = ($Results | Where-Object Status -eq "Success").Count
$Failed = ($Results | Where-Object Status -eq "Failed").Count

Write-Host ""
Write-Host "Done. Succeeded: $Ok  Failed: $Failed" -ForegroundColor Cyan
Write-Host "Log: $LogPath" -ForegroundColor Cyan
