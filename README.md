<!-- saved from url=(0023) https://kacos2000.github.io/WindowsTimeline/ --> 
<!-- https://guides.github.com/features/mastering-markdown/ --> 

## Windows 10 Timeline

**SQLite query to parse Windows 10 ([1803](https://support.microsoft.com/en-us/help/4099479/windows-10-update-history?ocid=update_setting_client)) Timeline's ActivityCache.db**

Either import the queries (.sql file) to your SQLite program, or Copy/Paste the code to a query tab.
Your software needs to support the SQLIte [JSON1 extension](https://www.sqlite.org/json1.html).


* [Windows timeline database query (WindowsTimeline.sql)](WindowsTimeline.sql)

*Screenshots of WindowsTimeline.sql*
![Preview1](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T1.JPG)


![Preview2](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T1a.JPG)

* [Extended windows timeline database query (WindowsTimeline2.sql)](WindowsTimeline2.sql)

*Screenshots of WindowsTimeline2.sql*
![Preview3 (Timeline2)](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T2.JPG)


![Preview4 (Timeline2)](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/T2a.JPG)

**Note:**  The output of the query can be exported as a TX or CSV so that can be used with [log2timeline](https://github.com/log2timeline/plaso/wiki/Windows-Packaged-Release), [TimelineExplorer](https://ericzimmerman.github.io/Software/TimelineExplorer.zip) or [MS Excel](https://products.office.com/en-ca/excel). For example, in [DB Browser for SQLite](http://sqlitebrowser.org/) at the bottom right corner, click on

![Export](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/e1.JPG) 

and select CSV. This will open this delimiter options window. After you make any needed changes (e.g. *select comma for the delimiter*), click ok, 

![Delimiter Options](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/e2.JPG)

and you will be presented with another window to select Folder and Filename to save the CSV file.

**SQLite Tables processed:**

- Activities,
- Activity_PackageID,
- ActivityOperation

**Other queries:**

1. [A re-formated Smartlookup view query](SmartLookup.sql)
2. [Activity_PackageID timeline query](Activity_PackageID_Timeline.sql)
3. [PackageID check](PackageID.sql)


**Tested on:**
- [DB Browser for SQLite](http://sqlitebrowser.org/),
- [SQLiteStudio](https://sqlitestudio.pl/index.rvt) as well as
- [SQLite Expert Pro with the JSON1 extension](http://www.sqliteexpert.com/extensions/)
- and Microsoft Windows 10 version [1803](https://support.microsoft.com/en-us/help/4099479/windows-10-update-history?ocid=update_setting_client) (OS builds from 17134.48 to 17134.112)

[**Documentation**](WindowsTimeline.pdf) **and analysis of the database and its entries** (*.pdf file*)

**Status**
- [x] Queries completed. 
- [ ] Decoding of [QuickXOR](https://github.com/microsoftgraph/microsoft-graph-docs/blob/master/api-reference/v1.0/resources/hashes.md) field values (e.g. *FileShellLink, PlatformDeviceID, ‘AppActivityId and PackageIDHash*)

