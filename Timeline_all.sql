-- SQLite query to get any useful results from MS Windows 1803 Timeline feature's database (ActivitiesCache.db).
-- Dates/Times in the database are stored in Unixepoch and UTC by default. 
-- Using the 'localtime" in the field converts it to our TimeZone.
-- The 'DeviceID' can be found in the user’s NTUSER.dat at
-- Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\
-- The Query uses the SQLite JSON1 extension to parse information from the BLOBs found at 
-- the Activity and ActivityOperation tables. 
--
-- 308046B0AF4A39CB is Firefox as seen at 'SOFTWARE\RegisteredApplications'
--
-- Known folder GUIDs 
-- "https://docs.microsoft.com/en-us/dotnet/framework/winforms/controls/known-folder-guids-for-file-dialog-custom-places"
--
-- Any Entries removed from the Timeline are copied from the Activity table to the ActivityOperation table until
-- (assumption here) they either expire or are uploaded to the Cloud.
-- Any ActivityOperation table's ETAGs that also exist in the Activity table are marked as Removed. Also, according to the Smartlookup 
-- view all entries in the Activity Table are marked as NOT in the upload queue (The UserActivity has not yet been published), 
-- but all entries in the ActivityOperation table minus the ones listed as 'Deleted') are marked 
-- as in the upload queue (The UserActivity has been published on this (or another) device).
-- https://docs.microsoft.com/en-us/uwp/api/windows.applicationmodel.useractivities.useractivitystate 
-- All ETAG entries from Activity and ActivityOperation tables remain in the Activity_PackageId even when they are deleted.
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2018

SELECT ActivityOperation.ETag AS Etag, -- This the ActivityOperation Table Query
       json_extract(ActivityOperation.Payload, '$.appDisplayName') AS [Program Name],
 	   case when length (json_extract(ActivityOperation.AppId, '$[1].application')) > 18 and length (json_extract(ActivityOperation.AppId, '$[1].application')) < 22 
	   then replace(replace(replace(replace(replace(json_extract(ActivityOperation.AppId, '$[0].application'),'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
 '{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
 '{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
 '{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
	   when json_extract(ActivityOperation.AppId, '$[1].application')  = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'	   
	   else  replace(replace(replace(replace(replace(json_extract(ActivityOperation.AppId, '$[1].application'),'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
 '{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
 '{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
 '{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') end AS Application,
       json_extract(ActivityOperation.Payload, '$.displayText') AS [File/title opened],
       json_extract(ActivityOperation.Payload, '$.description') AS [Full Path /Url],
	   json_extract(ActivityOperation.Payload, '$.activationUri') AS [AppUriHandler],
       Activity_PackageId.Platform AS Platform_id,
       ActivityOperation.OperationType AS Status,
       case when ActivityOperation.Id in(select Activity.Id from Activity where Activity.Id = ActivityOperation.Id) then 'Removed' end as 'WasRemoved',
	   Case when ActivityOperation.Id in(select Activity.Id from Activity where Activity.Id = ActivityOperation.Id) then null else 'Published' end AS 'UploadQueue',
	   CASE ActivityOperation.ActivityType WHEN 5 THEN 'Open App/File/Page' WHEN 6 THEN 'App In Use/Focus' ELSE 'Unknown yet' END AS [Activity type],
       case when cast((ActivityOperation.ExpirationTime - Activity_PackageId.ExpirationTime) as integer) <> 0 
	   and cast((Activity_PackageId.ExpirationTime - ActivityOperation.CreatedInCloud) as integer) then 'Created In Cloud' else '-' end as 'Cloud Status' ,
	   ActivityOperation.PlatformDeviceId as 'Device ID', 
	   json_extract(ActivityOperation.OriginalPayload, '$.type') AS Type,
       json_extract(ActivityOperation.OriginalPayload, '$.appDisplayName') AS [Original Program Name],
       json_extract(ActivityOperation.OriginalPayload, '$.displayText') AS [Original File/title opened],
       json_extract(ActivityOperation.OriginalPayload, '$.description') AS [Original Full Path /Url],
       time(json_extract(ActivityOperation.Payload, '$.activeDurationSeconds'),'unixepoch') AS [Active Duration],
       time(json_extract(ActivityOperation.OriginalPayload, '$.activeDurationSeconds'),'unixepoch') AS [Original Duration],
       CASE WHEN CAST ((ActivityOperation.EndTime - ActivityOperation.StartTime) AS INTEGER) < 0 THEN '-' 
	   ELSE time(CAST((ActivityOperation.EndTime - ActivityOperation.StartTime) AS INTEGER),'unixepoch') 
	   END AS [Calculated Duration],
       datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') AS StartTime, 
       datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') AS LastModified,
       CASE WHEN ActivityOperation.OriginalLastModifiedOnClient > 0 THEN datetime(ActivityOperation.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') ELSE '  -  ' END AS LastModifiedOnClient,
       CASE WHEN ActivityOperation.EndTime > 0 THEN datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') ELSE "-" END AS EndTime,
	   CASE WHEN ActivityOperation.CreatedInCloud > 0 THEN datetime(ActivityOperation.CreatedInCloud, 'unixepoch', 'localtime') ELSE "-" END AS CreatedInCloud,
	   json_extract(ActivityOperation.OriginalPayload, '$.userTimezone') AS TZone,
       CAST ( (ActivityOperation.ExpirationTime - ActivityOperation.LastModifiedTime) AS INTEGER) / '86400' AS [Expires In days],
       datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') AS [Expiration on PackageID],
       datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime') AS Expiration,
       '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' || substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' AS [Timeline Entry unique GUID]
	FROM Activity_PackageId
	JOIN ActivityOperation ON Activity_PackageId.ActivityId = ActivityOperation.Id  
	
WHERE Activity_PackageId.Platform = json_extract(ActivityOperation.AppId, '$[0].platform') AND Activity_PackageId.ActivityId = ActivityOperation.Id

UNION  -- Join Activity & ActivityOperation Queries to get results from both Tables

SELECT Activity.ETag AS Etag,  -- This the Activity Table Query
       json_extract(Activity.Payload, '$.appDisplayName') AS [Program Name],
       case when length (json_extract(Activity.AppId, '$[0].application')) > 18 and 
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
	   json_extract(Activity.Payload, '$.activationUri') AS [AppUriHandler],
       Activity_PackageId.Platform AS Platform_id,
       Activity.ActivityStatus AS Status,
	   null as 'WasRemoved',
       'New' as 'Upload Queue',  
	   CASE Activity.ActivityType WHEN 5 THEN 'Open App/File/Page' WHEN 6 THEN 'App In Use/Focus' ELSE 'Unknown yet' END AS [Activity type],
       case when cast((Activity.ExpirationTime - Activity_PackageId.ExpirationTime) as integer) <> 0 
	   and cast((Activity_PackageId.ExpirationTime - Activity.CreatedInCloud) as integer) then 'Created In Cloud' else '-' end as 'Cloud Status' ,
	   Activity.PlatformDeviceId as 'Device ID', 
       json_extract(Activity.OriginalPayload, '$.type') AS Type,
       json_extract(Activity.OriginalPayload, '$.appDisplayName') AS [Original Program Name],
       json_extract(Activity.OriginalPayload, '$.displayText') AS [Original File/title opened],
       json_extract(Activity.OriginalPayload, '$.description') AS [Original Full Path /Url],
       time(json_extract(Activity.Payload, '$.activeDurationSeconds'),'unixepoch') AS [Active Duration],
       time(json_extract(Activity.OriginalPayload, '$.activeDurationSeconds'),'unixepoch' ) AS [Original Duration],       
	   CASE WHEN CAST ((Activity.EndTime - Activity.StartTime) AS INTEGER) < 0 THEN '-' 
	   ELSE time(CAST((Activity.EndTime - Activity.StartTime) AS INTEGER),'unixepoch') 
	   END AS [Calculated Duration],
       datetime(Activity.StartTime, 'unixepoch', 'localtime') AS StartTime,
       datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime') AS LastModified,
       CASE WHEN Activity.OriginalLastModifiedOnClient > 0 THEN datetime(Activity.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') ELSE '  -  ' END AS LastModifiedOnClient,
       CASE WHEN Activity.EndTime > 0 THEN datetime(Activity.EndTime, 'unixepoch', 'localtime') ELSE "-" END AS EndTime,
	   CASE WHEN Activity.CreatedInCloud > 0 THEN datetime(Activity.CreatedInCloud, 'unixepoch', 'localtime') ELSE "-" END AS CreatedInCloud,
       json_extract(Activity.OriginalPayload, '$.userTimezone') AS TZone,
       CAST ( (Activity.ExpirationTime - Activity.LastModifiedTime) AS INTEGER) / '86400' AS [Expires In days],
       datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') AS [Expiration on PackageID],
       datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') AS Expiration,
       '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' || substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' || substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' AS [Timeline Entry unique GUID]
	FROM Activity_PackageId
    JOIN        Activity ON Activity_PackageId.ActivityId = Activity.Id  
	WHERE Activity_PackageId.Platform = json_extract(Activity.AppId, '$[0].platform') AND Activity_PackageId.ActivityId = Activity.Id
 
 ORDER BY Etag DESC;  -- Edit this line to change the sorting 
 
-- EOF