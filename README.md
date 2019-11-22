<!-- saved from url=(0045) https://kacos2000.github.io/WindowsTimeline/ --> 
<!-- https://guides.github.com/features/mastering-markdown/ --> 

## Windows 10 Timeline ## 

* ### [WindowsTimeline paser](https://github.com/kacos2000/WindowsTimeline/releases/download/v1.0.18/WindowsTimeline.exe) ###
    ![T](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T.JPG)<br>
    
    Works with any ActivitiesCache.db *(Windows 1803/1809/1903/1909 ..)*<br>
        - Decodes Clipboard Text<br>
        - Matches dB device information with data from the registry *(HKCU or NTuser.dat)*<br>
        - Shows all the important information from JSON blobs ..<br>
        - Optionally exports output to "|" delimited .csv in a timestamped folder in the form of "Timeline-dd-MMM-yyyyTHH-mm-ss".<br>

    Parses:
        - Standalone ActivitiesCache.db<br>
        - CurrentUser's selected ActivitiesCache.db with matching registry (HKCU) device entries<br>
        - Standalone ActivitiesCache.db with offline NTUser.dat device entries<br>
        
    Note1: Requires "[System.Data.SQLite](https://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki)". If not available, it will download and install automatically.<br>
    Note2: Runs on Windows 10 x64 <br>

___________________________________________________________________________________________  

**SQLite queries to parse Windows 10 (*[1803+](https://support.microsoft.com/en-us/help/4099479/windows-10-update-history?ocid=update_setting_client)*) Timeline's ActivitiesCache.db Database**

Either import the queries (*.sql file*) to your SQLite program, or *Copy/Paste* the code to a query tab.
Your software needs to support the SQLIte [JSON1 extension](https://www.sqlite.org/json1.html).

* ### [Windows timeline database query (WindowsTimeline.sql)](WindowsTimeline.sql) ###
    Updated to work with Win10  v1903 *(Build 19023.1)* <br>
    
    *Screenshots of WindowsTimeline.sql*
    ![Preview1](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T1.JPG)


    ![Preview2](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T1a.JPG)


**SQLite Tables processed:**

- Activities,
- Activity_PackageID,
- ActivityOperation

___________________________________________________________________________________________  

   [![Windows 10 Activity Timeline: An Investigator's Gold Mine](http://img.youtube.com/vi/-vsXFrOZOtc/0.jpg)](http://www.youtube.com/watch?v=-vsXFrOZOtc "BlackBag Webinar")<br>  
   A presentation of Windows Timeline from [BlackBag](https://www.blackbagtech.com/).
___________________________________________________________________________________________  

#### NEW (5/2019) #### 
[**>> Revised query <<**](https://github.com/kacos2000/WindowsTimeline/blob/master/Timeline.sql) for Windows Timeline - works with all versions (1803,1809,1903+) and is based on the smartlookup view #dfir. (Tested on Win10 pro 1903 *(Build 19023.1)*) <br>
 
   * **ActivityTypes observed:**
   
        - **2**  (Notifications) *{seen only in Win10 v1709}*
        - **5**  (Open Application/File/Webpage)
        - **6**  (Application in Use/Focus)
        - **10** (Clipboard Text - for a duration of 43200 seconds or 12 hours exactly)
        - **11,12,15** Windows System operations such as:
            - Microsoft.Credentials.Vault
            - Microsoft.Credentials.WiFi
            - Microsoft.Default
            - Microsoft.Credentials
            - Microsoft.Personalization
            - Microsoft.Language
            - Microsoft.Accessibility*
        - **0,1,3,7,13** *unknown yet*
        - **16** (Copy/Paste Operation - Copy or Paste is shown in the Group field of the db)
      
   * **Windows versions (OSBuild*) supporting Timeline:**<br>
        - March 2019 Update (v1903 18875)<br>
        - October 2018 Update (v1809 - 17763)<br>
        - April 2018 Update (v1803 - 17134)<br>
        
   * **Related**
        - [Win10 YourPhone app](https://github.com/kacos2000/Win10/blob/master/YourPhone/readme.md)
        - [Win10 Notifications](https://github.com/kacos2000/Win10/blob/master/Notifications/readme.md).
        
        
___________________________________________________________________________________________  


**Other queries (Win10 - 1803):** *(Build 19023.1)* 

1. [A re-formated Smartlookup view query](SmartLookup.sql) - Smartlookup is a view included in ActivitiesCache.db. This query makes it a bit more readable but does not extract the data in the BLOBs *(does not need the JSON1 extension)*. 
2. [Activity_PackageID timeline query](Activity_PackageID_Timeline.sql) - Creates a timeline according to the Expiry Dates in the Activity_PackageID table.
   ![pid](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/pid.JPG)
3. [PackageID check](PackageID.sql) - Check that the 'PackageID' in the 'Activity.AppId' json field has the same value as the 'Activity_PackageId' table's 'PackageName' field *(for x_exe and Windows_win32 entries)*.
4. [App_Platform](app_platform.sql) - A simple query to help understand the different PlatformID combinations (extracted from the AppID json field)

**Other queries (Win10 - 1809/1903):**

1. [A re-formated Smartlookup view query (1809/1903)](SmartLookup_1809.sql) - Smartlookup  for Win10 v1809 ActivitiesCache.db. *(does not need the JSON1 extension)*. 
2. [WindowsTimeline (1809/1903)](WindowsTimeline1809.sql) - Full SQLite query that works with Win10 v1809/1903 ActivitiesCache.db. Will not work with earlier Windows versions (1803) as the latest Windows version has more dB fields.
3. [WindowsTimeline (1903)](WindowsTimeline1903.sql) - Full SQLite query that works with Win10 v1903 ActivitiesCache.db. Will not work with earlier Windows versions (1803/1809) as the latest Windows version 1903 (19H1) has more dB fields. Now copy/paste operations can be seen as well as clipboard text (Base64 encoded):

      ![1903_screenshot](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/1903b.JPG)
      
      *-->* [Clipboard copy/paste operations (1903)](clipboard1903.sql) - SQLite query to get just clipboard related data.
 __________________________________________________________________________________________
   - About the clipboard sync:<br>
         * [Clipboard in Windows 10](https://support.microsoft.com/en-us/help/4028529/windows-10-clipboard)<br>
         * [Get help with clipboard (Applies to: Windows 10)](https://support.microsoft.com/en-us/help/4464215/windows-10-get-help-with-clipboard)<br>
         * [Using Windows 10’s New Clipboard: History and Cloud Sync](https://www.howtogeek.com/351978/using-windows-10s-new-clipboard-history-and-cloud-sync/)<br>

**Tested on:**
- [DB Browser for SQLite](http://sqlitebrowser.org/) 3.10.1,
- [SQLiteStudio](https://sqlitestudio.pl/index.rvt) as well as
- [SQLite Expert Pro with the JSON1 extension](http://www.sqliteexpert.com/extensions/)
- and Microsoft Windows 10 version [1803, 1903](https://support.microsoft.com/en-us/help/4099479/windows-10-update-history?ocid=update_setting_client) (OS builds from 17134.48 to 17134.254) and version 1809 (Insider's Build 17754.1) and 1903 (19023.1)
___________________________________________________________________________________________

  **Note:**  The output of the queries can be exported as a TX or CSV so that it can be used with [log2timeline](https://github.com/log2timeline/plaso/wiki/Windows-Packaged-Release), [TimelineExplorer](https://ericzimmerman.github.io/Software/TimelineExplorer.zip) or [MS Excel](https://products.office.com/en-ca/excel). For example, in [DB Browser for SQLite](http://sqlitebrowser.org/) at the bottom right corner, click on

  ![Export](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/e1.JPG) 

  and select CSV. This will open this delimiter options window. After you make any needed changes (e.g. *select comma as the delimiter*), click ok, 

  ![Delimiter Options](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/e2.JPG)

  and you will be presented with another window to select Folder and Filename to save the CSV file.
 __________________________________________________________________________________________

* ### Documentation ###
   
   - [WindowsTimeline.pdf](WindowsTimeline.pdf) - Documentation for the database and its entries. *Updated with information for the ~upcoming~ Win10 v1809 & v1903 upgrades.*
   - [A Forensic Exploration of the Microsoft Windows 10 Timeline](https://onlinelibrary.wiley.com/doi/abs/10.1111/1556-4029.13875) -     (Journal of Forensic Sciences DOI:10.1111/1556-4029.13875) - *(Win10 1803)*<br>
     __________________________________________________________________________________________
* ### PowerShell scripts *(Win10 - 1803,1809,1903+)* ###
   
   :shipit: Require SQLite3.exe <br> Note: *The PowerShell scripts are not the fastest way to parse Windows Timeline (~16min for a 10500 entry db)*
   * **[Instructions](http://www.sqlitetutorial.net/download-install-sqlite/)** *(How To Download & Install SQLite)*
       * ![command-line shell](http://www.sqlitetutorial.net/wp-content/uploads/2018/04/SQLite3-Help-command.png)
       
       **Note1** - [Add C:\sqlite to the system PATH](https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/)<br>
       **Note2** - After you install the latest SQLite3.exe, check the version from inside powershell
      by running `SQLite3.exe -version` (you may already have an older version in your Path - you can check that by running     [FindSQLite3.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/FindSQLite3.ps1))        

        
  * ### **[WindowsTimeline.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WindowsTimeline.ps1)** ### 
    Powershell script to check the Platform DeviceID values in the database against the HKCU DeviceCache entries in the registry. ~~It appears that Type 8 entries are Smartphones, type 9 Full Sized PCs and type 15 Laptops)~~. <br>*Note that Platform Device IDs representing a specific device change over time*. 
    
    * Note: According to the Connected [Devices Platform specification](https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/MS-CDP/[MS-CDP].pdf) these are the device types. Curiously, type 15 is not in that list:<br>
    
      - 1.Xbox One
      - 6.Apple iPhone
      - 7.Apple iPad 
      - 8.Android device
      - 9.Windows 10 Desktop
      - 11.Windows 10 Phone 
      - 12.Linux device
      - 13.Windows IoT
      - 14.Surface Hub 

    ![.ps1 results](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/WT.JPG) 
   
   * ### **[WinTimelineLocal.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WinTimelineLocal.ps1)** ###
     Powershell script that runs a simple SQLite query against one of the local ActivitiesCache.db's available to the user, and adds info for the PlatformID from the registry. Json fields are parsed with Powershell's convertfrom-json.<br>
     08/19 Updated to decode Win10 1903 Clipboard entries from Base64 to Text<br>
     ![p](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/p1.JPG)
   
   * ### **[WinTimelineOffline.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WinTimelineOffline.ps1)** ###
     Powershell script that runs a simple SQLite query against any user selected ActivitiesCache.db, and adds info for the PlatformID from the related, user selected, NTUser.dat file. Json fields are parsed with Powershell's convertfrom-json.<br>
08/19 Updated to decode Win10 1903 Clipboard entries from Base64 to Text<br>
 __________________________________________________________________________________________   
   *  [Devices](https://docs.microsoft.com/en-us/windows/uwp/design/devices/index) that support Universal Windows Platform (UWP)<br>
                * PCs and laptops *(Screen sizes 13” and greater)*<br>
                * Tablets and 2-in-1s *(Screen sizes: 7” to 13.3” for tablet, 13.3" and greater for 2-in-1)*<br>
                * Xbox and TV *(Screen sizes: 24" and up)*<br>
                * Phones and phablets *(Screen sizes: 4'' to 5'' for phone, 5.5'' to 7'' for phablet)*<br>
                * Surface Hub devices *(Screen sizes: 55” and 84'')*<br>
                * Windows IoT devices *(Screen sizes: 3.5'' or smaller, Some devices have no screen)*<br>
 __________________________________________________________________________________________
 
**Related Windows Apps**
- [Connected Devices](https://www.microsoft.com/en-us/p/connected-devices/9nblggh4tssg?activetab=pivot%3aoverviewtab)

**Status**
- **[x]** Queries completed.
- **[x]** Powershell - check DeviceIDs in both registry & database completed.
- **[x]** Powershell - decode Base64 Clipboard Text entries.
- **[x]** Win10 [Notifications Database](https://github.com/kacos2000/Win10/blob/master/Notifications/readme.md).
- **[ ]** ~~Decoding of [QuickXOR](https://github.com/microsoftgraph/microsoft-graph-docs/blob/master/api-reference/v1.0/resources/hashes.md) field values (e.g. *FileShellLink, PlatformDeviceID, ‘AppActivityId and PackageIDHash*)~~

