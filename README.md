<!-- saved from url=(0045) https://kacos2000.github.io/WindowsTimeline/ --> 
<!-- https://guides.github.com/features/mastering-markdown/ --> 

**Note:** *Starting in July 2021, if you have your activity history synced across your devices through your Microsoft account (MSA), you'll no longer have the option to upload new activity in Timeline. You'll still be able to use Timeline and see your activity history (information about recent apps, websites and files) on your local device.  AAD-connected accounts won't be impacted. [source](https://support.microsoft.com/en-us/windows/get-help-with-timeline-febc28db-034c-d2b0-3bbe-79aa0c501039)*<br>

## Windows 10 Timeline ## 

* ### [WindowsTimeline parser *(WindowsTimeline.exe)*](https://github.com/kacos2000/WindowsTimeline/releases) ###
    ![T](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T.JPG)<br>
    ![T](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/notif2.JPG)<br>
 
    Works with any ActivitiesCache.db *(Windows 1703/1709/1803/1809/1903/1909/2004 ..)*<br>
        - Decodes Clipboard Text<br>
        - Matches dB device information with data from the registry *(HKCU or NTuser.dat)*<br>
        - Shows all the important information from JSON blobs ..<br>
        - Optionally exports output to "|" delimited .csv in a timestamped folder in the form of "WindowsTimeline_dd-MMM-yyyyTHH-mm-ss".<br>

    Parses:<br>
        - Standalone ActivitiesCache.db<br>
        - CurrentUser's selected ActivitiesCache.db with matching registry (HKCU) device entries<br>
        - Standalone ActivitiesCache.db with offline NTUser.dat device entries<br>
          
    Note1: Requires "[System.Data.SQLite.dll](https://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki)". <br>*If it's not available, it show prompt to download and install automatically.*<br> *Installation path:* `C:\Program Files\System.Data.SQLite\2010\bin\`<br>
    Note2: Runs on Windows 10 x64 <br>

   * **ActivityTypes observed:**
   
        - **2**  (Notification) 
        - **3**  (Mobile Device Backup ?/azure authentication) 
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
        - **0,1,4,7,8,9,13** *unknown yet*
        - **16** (Copy/Paste Operation - Copy or Paste is shown in the Group field of the db)
        
    * **Device Types:** <br>
    (According to the Connected [Devices Platform specification](https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/MS-CDP/[MS-CDP].pdf) & observation)* <br>
    
      - 0.Windows 10X *(dual screen)* device *(Observed & Verified)*
      - 1.Xbox One *(Verified)*
      - 6.Apple iPhone
      - 7.Apple iPad 
      - 8.Android device *(Verified)*
      - 9.Windows 10 Desktop *(Verified)*
      - 11.Windows 10 Phone 
      - 12.Linux device
      - 13.Windows IoT
      - 14.Surface Hub 
      - 15.Windows 10 Laptop PC *(Observed & Verified)*1
      - 16.Windows 10 Tablet PC *(Observed & Verified)* <br><br>
      
      *[Windows.EDB](https://github.com/kacos2000/WinEDB) has the same info but in text form eg:*

        | Field Name | Field Value|
        |------------| -----------|
        |4124-System_ActivityHistory_DeviceMake|	HP|
        |4125-System_ActivityHistory_DeviceModel|	HP 250 G6 Notebook PC|
        |4126-System_ActivityHistory_DeviceName|	DESKTOP-HL2LCVA|
        |4127-System_ActivityHistory_DeviceType|	Laptop|


 * ### [Clippy *(previously 'WindowsTimeline Clipboard Text Carver')*](https://github.com/kacos2000/WindowsTimeline/releases) ### 
    ![T](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/Clips.JPG)<br>  
    
    * Retrieves current & deleted Clipboard text entries from an ActivitiesCache db or db-wal file.
    * Displays offset of entry in the file & decoded text
    * Allows Copy of a selection or all of the results
    * Allows export to "|" separated CSV

     Example:<br>
        - WindowsTimeline.exe: 15 clipboard text entries (SQLite query)<br>
        - Clippy.exe: 224 from the db & 19 from the db-wal<br>

_________________________________________________________________________________________   
   *  [Devices](https://docs.microsoft.com/en-us/windows/uwp/design/devices/index) that support Universal Windows Platform (UWP)<br>
                * PCs and laptops *(Screen sizes 13” and greater)*<br>
                * Tablets and 2-in-1s *(Screen sizes: 7” to 13.3” for tablet, 13.3" and greater for 2-in-1)*<br>
                * Xbox and TV *(Screen sizes: 24" and up)*<br>
                * Phones and phablets *(Screen sizes: 4'' to 5'' for phone, 5.5'' to 7'' for phablet)*<br>
                * Surface Hub devices *(Screen sizes: 55” and 84'')*<br>
                * Windows IoT devices *(Screen sizes: 3.5'' or smaller, Some devices have no screen)*<br>
  __________________________________________________________________________________________

* ### Documentation ###
   
   - [WindowsTimeline.pdf](WindowsTimeline.pdf) - Documentation for the database and its entries. *Updated with information for the ~upcoming~ Win10 v1809 & v1903+ upgrades.* *Updated with Clipboard History info*
   - [A Forensic Exploration of the Microsoft Windows 10 Timeline](https://onlinelibrary.wiley.com/doi/abs/10.1111/1556-4029.13875) -     (Journal of Forensic Sciences DOI:10.1111/1556-4029.13875) - *(Win10 1803)*<br>
   - [Exploring the Windows Activity Timeline, Part 1: The High Points](https://www.blackbagtech.com/blog/exploring-the-windows-activity-timeline-part-1-the-high-points/)<br>
   - [Exploring the Windows Activity Timeline, Part 2: Synching Across Devices](https://www.blackbagtech.com/blog/exploring-the-windows-activity-timeline-part-2-synching-across-devices/)<br>
   - [Exploring the Windows Activity Timeline, Part 3: Clipboard Craziness](https://www.blackbagtech.com/blog/exploring-the-windows-activity-timeline-part-2-clipboard-craziness/?utm_content=134912769&utm_medium=social&utm_source=twitter&hss_channel=tw-209890844)<br>
 __________________________________________________________________________________________
 
 * **Related**

    - [Win10 YourPhone app](https://github.com/kacos2000/Win10/blob/master/YourPhone/readme.md)<br>
    - [Win10 Notifications](https://github.com/kacos2000/Win10/blob/master/Notifications/readme.md).<br>
  __________________________________________________________________________________________
        

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
   
   **Related content:**

   * [![Windows 10 Activity Timeline: An Investigator's Gold Mine](http://img.youtube.com/vi/-vsXFrOZOtc/0.jpg)](http://www.youtube.com/watch?v=-vsXFrOZOtc "BlackBag Webinar")<br>  
      
   * [![Adaptive Cards for Timeline, Bots, and Beyond](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/ac-001.JPG)](https://channel9.msdn.com/events/Windows/Windows-Developer-Day-Fall-Creators-Update/WinDev003?term=timeline&lang-en=true)
   
   * [![](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/t1.JPG)](https://docs.microsoft.com/en-us/adaptive-cards/getting-started/windows)
   
   * [Build cross-device apps, powered by Project Rome](https://github.com/microsoft/project-rome/blob/master/cross-device_app_configuration.md)
___________________________________________________________________________________________  

#### (5/2019) #### 
[**>> Revised query <<**](https://github.com/kacos2000/WindowsTimeline/blob/master/Timeline.sql) for Windows Timeline - works with all versions (1803,1809,1903+) and is based on the smartlookup view. (Tested on Win10 pro 1903 *(Build 19023.1)*) <br>
     
   * **Windows versions (OSBuild*) supporting Timeline:**<br>
        - March 2019 Update (v1903 18875) .. <br>
        - October 2018 Update (v1809 - 17763)<br>
        - April 2018 Update (v1803 - 17134)<br>
        
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
- [DB Browser for SQLite](http://sqlitebrowser.org/) 3.10.1+,
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
* ### PowerShell scripts *(Win10 - 1803,1809,1903+)* ###
   
   :shipit: Require SQLite3.exe <br> Note: *The PowerShell scripts are not the fastest way to parse Windows Timeline (~16min for a 10500 entry db)*
   * **[Instructions](http://www.sqlitetutorial.net/download-install-sqlite/)** *(How To Download & Install SQLite)*
       * ![command-line shell](http://www.sqlitetutorial.net/wp-content/uploads/2018/04/SQLite3-Help-command.png)
       
       **Note1** - [Add C:\sqlite to the system PATH](https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/)<br>
       **Note2** - After you install the latest SQLite3.exe, check the version from inside powershell
      by running `SQLite3.exe -version` (you may already have an older version in your Path - you can check that by running     [FindSQLite3.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/FindSQLite3.ps1))        

        
  * ### **[WindowsTimeline.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WindowsTimeline.ps1)** ### 
    Powershell script to check the Platform DeviceID values in the database against the HKCU DeviceCache entries in the registry. ~~It appears that Type 8 entries are Smartphones, type 9 Full Sized PCs and type 15 Laptops)~~. <br>*Note that Platform Device IDs representing a specific device change over time*. 
    
    ![.ps1 results](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/WT.JPG) 
   
   * ### **[WinTimelineLocal.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WinTimelineLocal.ps1)** ###
     Powershell script that runs a simple SQLite query against one of the local ActivitiesCache.db's available to the user, and adds info for the PlatformID from the registry. Json fields are parsed with Powershell's convertfrom-json.<br>
     08/19 Updated to decode Win10 1903 Clipboard entries from Base64 to Text<br>
     ![p](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/p1.JPG)
   
   * ### **[WinTimelineOffline.ps1](https://github.com/kacos2000/WindowsTimeline/blob/master/WinTimelineOffline.ps1)** ###
     Powershell script that runs a simple SQLite query against any user selected ActivitiesCache.db, and adds info for the PlatformID from the related, user selected, NTUser.dat file. Json fields are parsed with Powershell's convertfrom-json.<br>
08/19 Updated to decode Win10 1903 Clipboard entries from Base64 to Text<br>
 
**Related Windows Apps**
- [Connected Devices](https://www.microsoft.com/en-us/p/connected-devices/9nblggh4tssg?activetab=pivot%3aoverviewtab)

**Related to Windows Timeline**
- [Windows Search database Windows.EDB](https://github.com/kacos2000/WinEDB)<br>
sample entry:

   ![image](https://user-images.githubusercontent.com/11378310/209337528-13cecac3-53e9-47bd-a2cd-544484972d43.png)




**Status**
- **[x]** Queries completed.
- **[x]** Powershell - check DeviceIDs in both registry & database completed.
- **[x]** Powershell - decode Base64 Clipboard Text entries.
- **[x]** Win10 [Notifications Database](https://github.com/kacos2000/Win10/blob/master/Notifications/readme.md).
- **[ ]** ~~Decoding of [QuickXOR](https://github.com/microsoftgraph/microsoft-graph-docs/blob/master/api-reference/v1.0/resources/hashes.md) field values~~

