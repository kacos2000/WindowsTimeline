<!-- saved from url=(0045) https://kacos2000.github.io/WindowsTimeline/ --> 
<!-- https://guides.github.com/features/mastering-markdown/ --> 

## Windows 10 Timeline ## 

**SQLite queries to parse Windows 10 (*[1803+](https://support.microsoft.com/en-us/help/4099479/windows-10-update-history?ocid=update_setting_client)*) Timeline's ActivitiesCache.db Database**

Either import the queries (*.sql file*) to your SQLite program, or *Copy/Paste* the code to a query tab.
Your software needs to support the SQLIte [JSON1 extension](https://www.sqlite.org/json1.html).

### - [Windows timeline database query (WindowsTimeline.sql)](WindowsTimeline.sql) ###

  *Screenshots of WindowsTimeline.sql*
  ![Preview1](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T1.JPG)


  ![Preview2](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T1a.JPG)

### - [Extended windows timeline database query (WindowsTimeline2.sql)](WindowsTimeline2.sql) ###

  *Screenshots of WindowsTimeline2.sql*
  ![Preview3 (Timeline2)](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T2.JPG)


  ![Preview4 (Timeline2)](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T2a.JPG)
  
___________________________________________________________________________________________  

**SQLite Tables processed:**

- Activities,
- Activity_PackageID,
- ActivityOperation

**Other queries:**

1. [A re-formated Smartlookup view query](SmartLookup.sql) - Smartlookup is a view included in ActivitiesCache.db. This query makes it a bit more readable but does not extract the data in the BLOBs *(does not need the JSON1 extension)*. 
2. [Activity_PackageID timeline query](Activity_PackageID_Timeline.sql) - Creates a timeline according to the Expiry Dates in the Activity_PackageID table.
3. [PackageID check](PackageID.sql) - Check that the 'PackageID' in the 'Activity.AppId' json field has the same value as the 'Activity_PackageId' table's 'PackageName' field *(for x_exe and Windows_win32 entries)*.
4. [App_Platform](app_platform.sql) - A simple query to help understand the different PlatformID combinations (extracted from the AppID json field)


**Tested on:**
- [DB Browser for SQLite](http://sqlitebrowser.org/),
- [SQLiteStudio](https://sqlitestudio.pl/index.rvt) as well as
- [SQLite Expert Pro with the JSON1 extension](http://www.sqliteexpert.com/extensions/)
- and Microsoft Windows 10 version [1803](https://support.microsoft.com/en-us/help/4099479/windows-10-update-history?ocid=update_setting_client) (OS builds from 17134.48 to 17134.191)
___________________________________________________________________________________________

  **Note:**  The output of the queries can be exported as a TX or CSV so that it can be used with [log2timeline](https://github.com/log2timeline/plaso/wiki/Windows-Packaged-Release), [TimelineExplorer](https://ericzimmerman.github.io/Software/TimelineExplorer.zip) or [MS Excel](https://products.office.com/en-ca/excel). For example, in [DB Browser for SQLite](http://sqlitebrowser.org/) at the bottom right corner, click on

  ![Export](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/e1.JPG) 

  and select CSV. This will open this delimiter options window. After you make any needed changes (e.g. *select comma as the delimiter*), click ok, 

  ![Delimiter Options](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/e2.JPG)

  and you will be presented with another window to select Folder and Filename to save the CSV file.
 __________________________________________________________________________________________

###  - [Documentation](WindowsTimeline.pdf) ###
   :notebook: **for the database and its entries** (*.pdf file*)
   
   [A Forensic Exploration of the Microsoft Windows 10 Timeline](https://onlinelibrary.wiley.com/doi/abs/10.1111/1556-4029.13875)*<br>
    *(Journal of Forensic Sciences DOI:10.1111/1556-4029.13875)*<br>
     __________________________________________________________________________________________
###  - PowerShell scripts ###
   
   :shipit: Require SQLite3.exe <br> Note: *The PowerShell scripts are not the fastest way to parse Windows Timeline (~16min for a 10500 entry db)*
   * **[Instructions](http://www.sqlitetutorial.net/download-install-sqlite/)** *(How To Download & Install SQLite)*
       * ![command-line shell](http://www.sqlitetutorial.net/wp-content/uploads/2018/04/SQLite3-Help-command.png)
       
       **Note1** *- [Add C:\sqlite to the system PATH](https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/)<br>
       **Note2** *- After you install the latest SQLite3.exe, check the version from inside powershell
      by running `SQLite3.exe -version` (you may already have an older version in your Path - you can check that by running     [FindSQLite3.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/FindSQLite3.ps1))        
      
  ### - **[WindowsTimeline.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WindowsTimeline.ps1)** ### 
  Powershell script to check the Platform DeviceID values in the database against the HKCU DeviceCache entries in the registry. *(From testing, it seems that Type 9 entries are Full Sized PCs while Type 15 entries are Laptops)*. It is evident that after a while Platform Device IDs representing a specific device change.

   ![.ps1 results](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/WT.JPG) 
   
   ### - **[WinTimelineLocal.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WinTimelineLocal.ps1)** ###
   Powershell script that runs a simple SQLite query against one of the local ActivitiesCache.db's available to the user, and adds info for the PlatformID from the registry. Json fields are parsed with Powershell's convertfrom-json.
   ### - **[WinTimelineOffline.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WinTimelineOffline.ps1)** ###
   Powershell script that runs a simple SQLite query against any user selected ActivitiesCache.db, and adds info for the PlatformID from a related, user selected NTUser.dat file. Json fields are parsed with Powershell's convertfrom-json.
   
   
 __________________________________________________________________________________________   
   -  [Devices](https://docs.microsoft.com/en-us/windows/uwp/design/devices/index) that support Universal Windows Platform (UWP)<br>
                * PCs and laptops *(Screen sizes 13” and greater)*<br>
                * Tablets and 2-in-1s *(Screen sizes: 7” to 13.3” for tablet, 13.3" and greater for 2-in-1)*<br>
                * Xbox and TV *(Screen sizes: 24" and up)*<br>
                * Phones and phablets *(Screen sizes: 4'' to 5'' for phone, 5.5'' to 7'' for phablet)*<br>
                * Surface Hub devices *(Screen sizes: 55” and 84'')*<br>
                * Windows IoT devices *(Screen sizes: 3.5'' or smaller, Some devices have no screen)*<br>
 __________________________________________________________________________________________

**Status**
- **[x]** Queries completed.
- **[x]** Powershell scripts to check DeviceIDs in both registry & database completed.
- **[ ]** ~~Decoding of [QuickXOR](https://github.com/microsoftgraph/microsoft-graph-docs/blob/master/api-reference/v1.0/resources/hashes.md) field values (e.g. *FileShellLink, PlatformDeviceID, ‘AppActivityId and PackageIDHash*)~~

