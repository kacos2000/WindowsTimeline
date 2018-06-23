<!-- saved from url=(0023) https://github.com/kacos2000/WindowsTimeline --> 
#DFIR 

## Windows 10 Timeline

SQLite query to parse Windows 10 (1803) Timeline's ActivityCache.db


![Preview1](Preview1.jpg)

![Preview2](Preview2.jpg)


Tables processed:

- Activities,
- Activity_PackageID,
- ActivityOperation

Either import '[The windows timeline query](WindowsTimeline.sql) to your SQLite program, or Copy Paste the code to a query tab.
Your software needs to support the SQLIte [JSON1 extension](https://www.sqlite.org/json1.html).

Tested on:
[DB Browser for SQLite](http://sqlitebrowser.org/),
[SQLiteStudio](https://sqlitestudio.pl/index.rvt) as well as
[SQLite Expert Pro with the JSON1 extension](http://www.sqliteexpert.com/extensions/)

[Documentation in pdf](WindowsTimeline.pdf)
