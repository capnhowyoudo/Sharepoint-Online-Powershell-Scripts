# How to restore SharePoint Recycle Bin items deleted by a specific user

When a user (here: Alex Morgan) deletes a large number of files, restoring them one by one in the SharePoint UI is tedious. With PnP PowerShell you can list the Recycle Bin items in a grid, filter by the person who deleted them, and restore everything in one go.

## Prerequisites

- [PnP PowerShell](https://pnp.github.io/powershell/) installed
- An Entra ID app registration for PnP PowerShell. The **Client ID** of this app is required in the script when connecting with `Connect-PnPOnline`. If you don't have one yet, register it with:

  ```powershell
  Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP PowerShell" -SharePointDelegatePermissions "AllSites.FullControl" -Tenant contoso.onmicrosoft.com
  ```

  Note down the Client ID that is returned.
- Permission on the site to restore items from the Recycle Bin

## 1. Run the command

The script connects to the site with your Client ID, lists all Recycle Bin items, shows them in a grid, and restores whatever you select:

```powershell
# Variables
$SiteURL = "https://contoso.sharepoint.com/sites/Marketing"
$ClientID = "a1b2c3d4-1111-2222-3333-444455556666"

# Connect to SharePoint Online site
Connect-PnPOnline -Url $SiteURL -Interactive -ClientId $ClientID

Get-PnPRecycleBinItem |
    Select-Object Title, ID, AuthorEmail, DeletedByEmail, DeletedDate, DirName |
        Out-GridView -PassThru |
            ForEach-Object { Restore-PnPRecycleBinItem -Identity $_.Id.Guid -Force }
```

> **Note:** `Id` must be part of the selected properties, otherwise the restore step cannot identify the items.

## 2. Open the grid

`Out-GridView` shows the Recycle Bin items with these columns:

| Column | Description |
|---|---|
| Title | Name of the deleted item |
| AuthorEmail | Who created the item |
| DeletedByEmail | Who deleted the item |
| DeletedDate | When the item was deleted |
| DirName | Original location |

Example content of the grid:

| Title | AuthorEmail | DeletedByEmail | DeletedDate | DirName |
|---|---|---|---|---|
| Budget-Q1.xlsx | jamie.rivera@contoso.onmicrosoft.com | jamie.rivera@contoso.onmicrosoft.com | 2024-03-12 10:15 | sites/Marketing/Shared Documents |
| Campaign-Brief.docx | jamie.rivera@contoso.onmicrosoft.com | jamie.rivera@contoso.onmicrosoft.com | 2024-03-12 10:22 | sites/Marketing/Shared Documents |
| Banner-01.png | jamie.rivera@contoso.onmicrosoft.com | alex.morgan@contoso.onmicrosoft.com | 2024-04-18 14:05 | sites/Marketing/Assets |
| Banner-02.png | jamie.rivera@contoso.onmicrosoft.com | alex.morgan@contoso.onmicrosoft.com | 2024-04-18 14:05 | sites/Marketing/Assets |
| Logo-Draft.svg | jamie.rivera@contoso.onmicrosoft.com | alex.morgan@contoso.onmicrosoft.com | 2024-04-18 14:06 | sites/Marketing/Assets |

Some items were deleted by `jamie.rivera@contoso.onmicrosoft.com`, others by `alex.morgan@contoso.onmicrosoft.com`. We only want to restore the items deleted by Alex Morgan.

## 3. Add a filter criteria

Now you can see the grid, where you can choose Alex Morgan as the deleter:

1. Click **Add criteria**.
2. Tick **DeletedByEmail**.
3. Click **Add**.

## 4. Filter by Alex Morgan's email address

1. In the new filter row, enter Alex Morgan's mail address (e.g. `alex.morgan`) in the **contains** field. The grid now only shows his or her deleted items.
2. Press **CTRL + A** to select all entries.
3. Confirm with **OK**.

## 5. Check the result

After doing this, the files which were deleted by Alex Morgan are restored!

Open the site's Recycle Bin in SharePoint to verify: the restored items (e.g. `Banner-01.png`, `Banner-02.png`, `Logo-Draft.svg`) no longer appear there, and only items deleted by other users (here: Jamie Rivera) remain.

| Name | Date deleted | Deleted by | Created by | Original location |
|---|---|---|---|---|
| Budget-Q1.xlsx | 3/12/2024 10:15 AM | Jamie Rivera | Jamie Rivera | sites/Marketing/Shared Documents |
| Campaign-Brief.docx | 3/12/2024 10:22 AM | Jamie Rivera | Jamie Rivera | sites/Marketing/Shared Documents |

## Tips

- Filter by **DeletedDate** or **DirName** as well to narrow the selection to a specific time window or library.
- Use the `contains` filter with only part of the address if you are unsure of the exact spelling.
- Test with a small selection first when working on production sites.
