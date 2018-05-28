-- Query of ActivitiesCache.db Activity_PackageId table
-- where the actual status of each entry is shown as:
-- 'New Activity'
-- 'Tile Removed'
-- 'In Upload Queue'
-- 'Archived' (until expiration time)
-- and sorted by Expiration Time

select
case when Activity_PackageId.ActivityId not in (select Activity.Id from activity) and Activity_PackageId.Platform 
then 'In Upload Queue - '||hex(Activity_PackageId.ActivityId) 
when Activity_PackageId.ActivityId not in (select ActivityOperation.Id from ActivityOperation) 
and Activity_PackageId.ActivityId not in (select Activity.Id from Activity) 
then 'Archived - '||hex(Activity_PackageId.ActivityId) 
when Activity_PackageId.ActivityId = (select Activity.Id from activity) 
and Activity_PackageId.ActivityId = (select ActivityOperation.Id from ActivityOperation)
then 'Tile Removed - '||hex(Activity_PackageId.ActivityId)
else 'New Activity - '||hex(Activity_PackageId.ActivityId)
end as 'ID',
Activity_PackageId.PackageName as 'PackageNameName',
datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') as 'ExpirationTime',
Activity_PackageId.Platform
from Activity_PackageId where Activity_PackageId.Platform in ('windows_win32', 'windows_universal', 'x_exe_path')
group by ID
order by ExpirationTime , ID

