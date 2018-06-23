<!-- saved from url=(0023) https://github.com/kacos2000/WindowsTimeline --> 
#DFIR 

## Windows 10 Timeline

SQLite query to parse Windows 10 (1803) Timeline's ActivityCache.db


![Preview1](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/Preview1.PNG)


![Preview2](https://raw.githubusercontent.com/kacos2000/WindowsTimeline/master/Preview2.PNG)


SQLite Tables processed:

- Activities,
- Activity_PackageID,
- ActivityOperation

Either import [the windows timeline database query](WindowsTimeline.sql) to your SQLite program, or Copy Paste the code to a query tab.
Your software needs to support the SQLIte [JSON1 extension](https://www.sqlite.org/json1.html).

Other queries:

- ![A formated Smartlookup view query](SmartLookup.sql)
- ![Activity_PackageID timeline query](Activity_PackageID_Timeline.sql)

Tested on:
[DB Browser for SQLite](http://sqlitebrowser.org/),
[SQLiteStudio](https://sqlitestudio.pl/index.rvt) as well as
[SQLite Expert Pro with the JSON1 extension](http://www.sqliteexpert.com/extensions/)

Full [Documentation](WindowsTimeline.pdf) and analysis of the database and its entries.

Licensed under [MIT license](licences/mit.txt).


