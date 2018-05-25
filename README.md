#DFIR Windows Timeline 

SQLite query to parse Windows 10 (1803) Timeline's ActivityCache.db

Tables processed:

Activities,
Activity_PackageID,
ActivityOperation

Either import 'WindowsTimeline.sql' to your SQLite program, or Copy Paste the code to the query window.
Your software needs to support the SQLIte JSON1 extension (https://www.sqlite.org/json1.html).

Tested on:
DB Browser for SQLite (http://sqlitebrowser.org/), and
SQLiteStudio (https://sqlitestudio.pl/index.rvt) as well as
SQLite Expert Pro with the JSON extension http://www.sqliteexpert.com/extensions/ 



-- EOF --
