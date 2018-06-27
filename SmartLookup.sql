-- SmartLookup View  
-- in easy to view format.
-- BLOBs and information stored in them needs manual extraction.
-- JSON1 extension is NOT required for this query to run.
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2018

select 
       '{'||hex(ActivityOperation.Id)||'}' as 'ID', 
       ActivityOperation.AppId, 
       ActivityOperation.PackageIdHash, 
       case when ActivityOperation.AppActivityId not like '%-%-%-%-%\%' then ActivityOperation.AppActivityId
		when Activity.AppActivityId not like '%-%-%-%-%' then ActivityOperation.AppActivityId
		else substr(ActivityOperation.AppActivityId , 38)
		end as 'Hash', 
       case ActivityOperation.ActivityType when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
	   else 'Unknown yet' end as 'Activity type', 
       case ActivityOperation.OperationType 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus', 
       ActivityOperation.ParentActivityId, 
       ActivityOperation.Tag, 
       ActivityOperation.MatchId, 
       datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModifiedTime',
       datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime')as 'ExpirationTime',
       ActivityOperation.Payload, 
       ActivityOperation.Priority, 
       Activity.IsLocalOnly, 
       ActivityOperation.PlatformDeviceId, 
       datetime(Activity.CreatedInCloud, 'unixepoch', 'localtime')as 'CreatedInCloud',
       datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') as 'EndTime',
       datetime(ActivityOperation.LastModifiedOnClient, 'unixepoch', 'localtime') as 'LastModifiedOnClient', 
       'Yes' AS IsInUploadQueue, 
       ActivityOperation.GroupAppActivityId, 
       ActivityOperation.ClipboardPayload, 
       ActivityOperation.EnterpriseId, 
       ActivityOperation.OriginalPayload, 
       ActivityOperation.OriginalLastModifiedOnClient, 
       ActivityOperation.ETag
from   ActivityOperation 
       left outer join Activity on ActivityOperation.Id = Activity.Id
union
select 
       '{'||hex(Activity.Id)||'}' as 'ID', 
       Activity.AppId, 
       Activity.PackageIdHash, 
       case when Activity.AppActivityId not like '%-%-%-%-%\%' then Activity.AppActivityId
		when Activity.AppActivityId not like '%-%-%-%-%' then Activity.AppActivityId
		else substr(Activity.AppActivityId , 38)
		end as 'Hash', 
       case Activity.ActivityType when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
	   else 'Unknown yet' end as 'Activity type', 
       case Activity.ActivityStatus 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus', 
       Activity.ParentActivityId, 
       Activity.Tag, 
       Activity.MatchId, 
       datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime')as 'LastModifiedTime',
       datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') as 'ExpirationTime',
       Activity.Payload, 
       Activity.Priority, 
       Activity.IsLocalOnly, 
       Activity.PlatformDeviceId, 
       datetime(Activity.CreatedInCloud, 'unixepoch', 'localtime') as 'CreatedInCloud',
       datetime(Activity.StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(Activity.EndTime, 'unixepoch', 'localtime') as 'EndTime',
       datetime(Activity.LastModifiedOnClient, 'unixepoch', 'localtime') as 'LastModifiedOnClient',
       'No' AS 'IsInUploadQueue', 
       Activity.GroupAppActivityId, 
       Activity.ClipboardPayload, 
       Activity.EnterpriseId, 
       Activity.OriginalPayload, 
       Activity.OriginalLastModifiedOnClient, 
       Activity.ETag
from   Activity
where  Activity.Id not in (select ActivityOperation.Id from ActivityOperation)
order by Etag desc

 
-- EOF
