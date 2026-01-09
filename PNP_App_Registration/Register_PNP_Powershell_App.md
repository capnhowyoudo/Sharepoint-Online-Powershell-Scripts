# Install Powershell 7+

  Run the below command in powershell

    iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"

# Uninstall the Legacy SharePointPnPPowerShellOnline Module
  
   Check if the classic PnP PowerShell module is installed with the below command:
  
     Get-Module SharePointPnPPowerShellOnline -ListAvailable | Select-Object Name,Version | Sort-Object Version -Descending

  This returns the Name and version of legacy PnP PowerShell installed on the machine (If any). Uninstall Any previous PnP PowerShell Modules for SharePoint Online installed:

     Uninstall-Module SharePointPnPPowerShellOnline -Force -AllVersions

# Install the New PnP PowerShell Module

  To install the new PnP PowerShell module, use:

    Install-Module PnP.PowerShell

# Register a new Azure AD Application ID and Grant Access to the tenant

  The final step is creating an Azure App ID that grants the tenant access to the Azure AD Application. Make sure you run the below command from an account that has access to create App IDs in your Entra ID Using Powershell 7

      Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP PowerShell" -SharePointDelegatePermissions "AllSites.FullControl" -Tenant Salaudeen.onmicrosoft.com -Interactive

  Replace the value for the -Tenant accordingly. 

  > :information_source: If you encounter the following error:
  >
  > " $${\color{red}Register-PnPEntraIDAppForInteractiveLogin: A parameter cannot be found that matches parameter name 'Interactive'}$$ "
  >
  > Remove the $${\color{yellow}-Interactive}$$ parameter from the cmdlet. 
  
  > :heavy_exclamation_mark: Make a note of the AppID created!

  <img width="759" height="512" alt="image" src="https://github.com/user-attachments/assets/3879e4a4-313c-4186-9f7a-8cdb0c41a572" />

  Executing the above cmdlet creates a new App ID, and you’ll be prompted to log in and provide consent for your tenant. To complete this step, you must log in with Global Admin (or Tenant Administrator) permissions.

  <img width="900" height="711" alt="image" src="https://github.com/user-attachments/assets/16b18768-55d5-4204-a352-0df89110d2c0" />

