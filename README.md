# Sharepoint-Online-Powershell-Scripts
A collection of PowerShell cmdlets and scripts designed for Share Point Online

:warning: Use At Your Own Risk — PowerShell Scripts

:heavy_exclamation_mark: I do not take credit for all of the scripts in this repository. Some scripts were created by others and may have been slightly modified—or not modified at all. Any script that was not originally written by me will retain the original author’s name in the notes section.

# Supported PowerShell: 
1. PowerShell 5.1 
2. PowerShell 7+

# Requirements

- PnP PowerShell module
- PNP App Registration
- PowerShell 7+
- Windows PowerShell 5.1
- Admin privileges (only if required by the script actions)


:information_source: In order to execute scripts using the PnP.PowerShell module, you must first provision and register a dedicated Entra ID Application within your tenant to establish a secure, authorized trust relationship.
Legacy authentication methods have been deprecated in favor of Modern Authentication (OAuth 2.0). By registering your own application, you maintain full control over the granular permissions and security scopes required for your automation tasks.

> 1. https://github.com/capnhowyoudo/Sharepoint-Online-Powershell-Scripts/blob/main/PNP_App_Registration/Register_PNP_Powershell_App.md
>    
> 2. Following the successful registration of your PnP Entra ID Application, you can establish a secure connection to your SharePoint environment using the following command:

:information_source: To establish a connection while working within Windows **PowerShell 5.1** or the **PowerShell ISE**, execute the following command:

    Connect-PnPOnline -Url "https://YOURTENANT.sharepoint.com" -Interactive -ClientId "YOUR-CLIENT-ID" 

:information_source: To establish a connection while working within Windows **PowerShell 7.2** in a default web browser session, execute the following command:

    Connect-PnPOnline -Url "https://YOURTENANT.sharepoint.com" -DeviceLogin -ClientId "YOUR-CLIENT-ID" -Tenant "YOUR-TENANT-NAME"

:information_source: To establish a connection while working within Windows **PowerShell 7.2** in a private session to avoid conflicts with other logged-in accounts, execute the following command:

    Start-Process "msedge.exe" "-inprivate https://microsoft.com/devicelogin"; Connect-PnPOnline -Url "https://YOURTENANT.sharepoint.com" -DeviceLogin -ClientId "YOUR-CLIENT-ID" -Tenant "YOUR-TENANT-NAME"
    
> Note that your default browser will still open automatically; simply ignore or close that window, switch to the Private/Incognito window that just opened, and enter the 8-digit code displayed in your PowerShell console.

# :warning: High-level disclaimer

These PowerShell scripts are provided as-is, without warranty of any kind. By running or using these scripts you accept full responsibility for any consequences — including data loss, system instability, security issues, or legal/regulatory impacts. Do not run these scripts on production systems unless you understand every line and have tested them in a safe environment.

Recommended precautions (must-read)

- Test in a sandbox or VM first (e.g., a disposable virtual machine or container).

- Back up important data before running anything that modifies files, system settings, the registry, or user accounts.

- Review the entire script line-by-line. Do not run blindly.

- Run with least privilege — only elevate to Administrator when absolutely necessary.

- Use -WhatIf / -Confirm switches in cmdlets that support them while testing.

- Use Get-ExecutionPolicy -List to check system policies and avoid changing global policies permanently.

- Prefer signed scripts — consider signing with an Authenticode certificate for production use.

- Use source control (Git) and code review for changes to the script.
