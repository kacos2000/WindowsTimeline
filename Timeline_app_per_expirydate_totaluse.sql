-- SQLite query to list the total duration of use of an application per day.
-- 
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2018

SELECT ActivityOperation.ETag AS Etag, -- This the ActivityOperation Table Query
       json_extract(ActivityOperation.Payload, '$.appDisplayName') AS [Program Name],
 	   case when json_extract(ActivityOperation.AppId, '$[0].application') = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'
	   when json_extract(ActivityOperation.AppId, '$[1].application') = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'
	   when length (json_extract(ActivityOperation.AppId, '$[1].application')) > 17 and length (json_extract(ActivityOperation.AppId, '$[1].application')) < 22 
	   then replace(replace(replace(replace(replace(json_extract(ActivityOperation.AppId, '$[0].application'),'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
 '{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
 '{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
 '{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
	   else  replace(replace(replace(replace(replace(json_extract(ActivityOperation.AppId, '$[1].application'),'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
 '{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
 '{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
 '{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') end AS Application,
       json_extract(ActivityOperation.Payload, '$.displayText') AS [File/title opened],
       json_extract(ActivityOperation.Payload, '$.description') AS [Full Path /Url],
	   time(sum(json_extract(ActivityOperation.Payload, '$.activeDurationSeconds')),'unixepoch') as 'TotalTime',
	   case json_extract(ActivityOperation.AppId, '$[0].platform') when 'afs_crossplatform' then 'Yes' when 'host' then 
	   (case json_extract(ActivityOperation.AppId, '$[1].platform') when 'afs_crossplatform' then'Yes' else null end) else null end as 'SyncEnabled',	   
       case when ActivityOperation.Id in(select Activity.Id from Activity where Activity.Id = ActivityOperation.Id) then 'Removed' end as 'WasRemoved',
	   Case when ActivityOperation.Id in(select Activity.Id from Activity where Activity.Id = ActivityOperation.Id) then null else 'In Queue' end AS 'UploadQueue',
	   CASE ActivityOperation.ActivityType WHEN 5 THEN 'Open App/File/Page' WHEN 6 THEN 'App In Use/Focus' ELSE 'Unknown yet' END AS [Activity type],
       time(json_extract(ActivityOperation.Payload, '$.activeDurationSeconds'),'unixepoch') AS [Active Duration],
       datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') AS StartTime, 
       datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') AS LastModified,
       CASE WHEN ActivityOperation.EndTime > 0 THEN datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') ELSE "-" END AS EndTime,
	   CASE WHEN ActivityOperation.CreatedInCloud > 0 THEN datetime(ActivityOperation.CreatedInCloud, 'unixepoch', 'localtime') ELSE "-" END AS CreatedInCloud,
       CAST ( (ActivityOperation.ExpirationTime - ActivityOperation.LastModifiedTime) AS INTEGER) / '86400' AS [Expires In days],
       datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') AS [Expiration on PackageID],
       datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime') AS Expiration,
	   hex(ActivityOperation.PackageIdHash) as 'Hash',
       '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' || substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' AS [Timeline Entry unique GUID]
	FROM Activity_PackageId
	JOIN ActivityOperation ON Activity_PackageId.ActivityId = ActivityOperation.Id  
	
WHERE Activity_PackageId.Platform = json_extract(ActivityOperation.AppId, '$[0].platform') AND Activity_PackageId.ActivityId = ActivityOperation.Id

UNION  -- Join Activity & ActivityOperation Queries to get results from both Tables

SELECT Activity.ETag AS Etag,  -- This the Activity Table Query
       json_extract(Activity.Payload, '$.appDisplayName') AS [Program Name],
       case when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'
	   when json_extract(Activity.AppId, '$[1].application') = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'
	   when length (json_extract(Activity.AppId, '$[0].application')) > 17 and 
	   length(json_extract(Activity.AppId, '$[0].application')) < 22 
	   then replace(replace(replace(replace(replace(json_extract(Activity.AppId, '$[1].application'),'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
 '{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
 '{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
 '{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
	   when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'
	   else  replace(replace(replace(replace(replace(json_extract(Activity.AppId, '$[0].application'),'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
 '{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
 '{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
 '{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') end AS Application,
       json_extract(Activity.Payload, '$.displayText') AS [File/title opened],
       json_extract(Activity.Payload, '$.description') AS [Full Path /Url],
	   time(sum(json_extract(Activity.Payload, '$.activeDurationSeconds')),'unixepoch') as 'TotalTime',
	   case json_extract(Activity.AppId, '$[0].platform') when 'afs_crossplatform' then 'Yes' when 'host' then 
	   (case json_extract(Activity.AppId, '$[1].platform') when 'afs_crossplatform' then'Yes' else null end) else null end as 'SyncEnabled',
	   null as 'WasRemoved',
       'No' as 'UploadQueue',  
	   CASE Activity.ActivityType WHEN 5 THEN 'Open App/File/Page' WHEN 6 THEN 'App In Use/Focus' ELSE 'Unknown yet' END AS [Activity type],
       time(json_extract(Activity.Payload, '$.activeDurationSeconds'),'unixepoch') AS [Active Duration],
       datetime(Activity.StartTime, 'unixepoch', 'localtime') AS StartTime,
       datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime') AS LastModified,
       CASE WHEN Activity.EndTime > 0 THEN datetime(Activity.EndTime, 'unixepoch', 'localtime') ELSE "-" END AS EndTime,
	   CASE WHEN Activity.CreatedInCloud > 0 THEN datetime(Activity.CreatedInCloud, 'unixepoch', 'localtime') ELSE "-" END AS CreatedInCloud,
       CAST ( (Activity.ExpirationTime - Activity.LastModifiedTime) AS INTEGER) / '86400' AS [Expires In days],
       datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') AS [Expiration on PackageID],
       datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') AS Expiration,
	   hex(activity.PackageIdHash) as 'Hash',
       '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' || substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' AS [Timeline Entry unique GUID]
	FROM Activity_PackageId
    JOIN        Activity ON Activity_PackageId.ActivityId = Activity.Id  
	WHERE Activity_PackageId.Platform = json_extract(Activity.AppId, '$[0].platform') AND Activity_PackageId.ActivityId = Activity.Id
 
 Group by Hash, date(Expiration, 'unixepoch')
 ORDER BY etag desc;  -- Edit this line to change the sorting 
 
-- EOF
