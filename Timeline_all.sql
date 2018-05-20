-- SQLite query to get any useful results from MS Windows 1803 Timeline feature's database (ActivitiesCache.db).
-- Dates/Times in the database are stored in Unixepoch and UTC by default. 
-- Using the 'localtime" in the field converts it to our TimeZone.
-- The 'DeviceID' can be found in the user’s NTUSER.dat at
-- Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\
-- The Query uses the SQLite JSON1 extension to parse information from the BLOBs found at 
-- the Activity and ActivityOperation tables. 
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2018

SELECT ActivityOperation.ETag AS Etag, -- This the ActivityOperation Query
       json_extract(ActivityOperation.Payload, '$.appDisplayName') AS [Program Name],
       
	   case when length (json_extract(ActivityOperation.AppId, '$[1].application')) > 18 and length (json_extract(ActivityOperation.AppId, '$[1].application')) < 22 
	   then json_extract(ActivityOperation.AppId, '$[0].application') 
	   when json_extract(ActivityOperation.AppId, '$[1].application')  = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'	   
	   
	   

	   else json_extract(ActivityOperation.AppId, '$[1].application') end AS Application,
	   
       json_extract(ActivityOperation.Payload, '$.displayText') AS [File/title opened],
       json_extract(ActivityOperation.Payload, '$.description') AS [Full Path /Url],
       Activity_PackageId.Platform AS Platform_id,
       ActivityOperation.OperationType AS Status,
       CASE ActivityOperation.ActivityType WHEN 5 THEN 'Open App/File/Page' WHEN 6 THEN 'App In Use/Focus' ELSE 'Unknown yet' END AS [Activity type],
       case when cast((ActivityOperation.ExpirationTime - Activity_PackageId.ExpirationTime) as integer) <> 0 
	   and cast((Activity_PackageId.ExpirationTime - ActivityOperation.CreatedInCloud) as integer) then 'Created In Cloud' else '-' end as 'Cloud Status' ,
	   ActivityOperation.PlatformDeviceId as 'Device ID', 
	   json_extract(ActivityOperation.OriginalPayload, '$.type') AS Type,
       json_extract(ActivityOperation.OriginalPayload, '$.appDisplayName') AS [Original Program Name],
       json_extract(ActivityOperation.OriginalPayload, '$.displayText') AS [Original File/title opened],
       json_extract(ActivityOperation.OriginalPayload, '$.description') AS [Original Full Path /Url],
       json_extract(ActivityOperation.Payload, '$.activeDurationSeconds') AS [Active Duration Secs],
       json_extract(ActivityOperation.Payload, '$.activeDurationSeconds') AS [Original Duration Secs],
       CASE WHEN CAST ( (ActivityOperation.EndTime - ActivityOperation.StartTime) AS INTEGER) < 0 THEN '-' ELSE CAST ( (ActivityOperation.EndTime - ActivityOperation.StartTime) AS INTEGER) END AS [Calculated Duration],
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

SELECT Activity.ETag AS Etag,  -- This the Activity Query
       json_extract(Activity.Payload, '$.appDisplayName') AS [Program Name],
       case when length (json_extract(Activity.AppId, '$[0].application')) > 18 and 
	   length(json_extract(Activity.AppId, '$[0].application')) < 22 
	   then json_extract(Activity.AppId, '$[1].application') 
	   when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' then 'Firefox-308046B0AF4A39CB'
	   else json_extract(Activity.AppId, '$[0].application') end AS Application,
       json_extract(Activity.Payload, '$.displayText') AS [File/title opened],
       json_extract(Activity.Payload, '$.description') AS [Full Path /Url],
       Activity_PackageId.Platform AS Platform_id,
       Activity.ActivityStatus AS Status,
       CASE Activity.ActivityType WHEN 5 THEN 'Open App/File/Page' WHEN 6 THEN 'App In Use/Focus' ELSE 'Unknown yet' END AS [Activity type],
       case when cast((Activity.ExpirationTime - Activity_PackageId.ExpirationTime) as integer) <> 0 
	   and cast((Activity_PackageId.ExpirationTime - Activity.CreatedInCloud) as integer) then 'Created In Cloud' else '-' end as 'Cloud Status' ,
	   Activity.PlatformDeviceId as 'Device ID', 
       json_extract(Activity.OriginalPayload, '$.type') AS Type,
       json_extract(Activity.OriginalPayload, '$.appDisplayName') AS [Original Program Name],
       json_extract(Activity.OriginalPayload, '$.displayText') AS [Original File/title opened],
       json_extract(Activity.OriginalPayload, '$.description') AS [Original Full Path /Url],
       json_extract(Activity.Payload, '$.activeDurationSeconds') AS [Active Duration Secs],
       json_extract(Activity.OriginalPayload, '$.activeDurationSeconds') AS [Original Duration Secs],
       CASE WHEN CAST ( (Activity.EndTime - Activity.StartTime) AS INTEGER) < 0 THEN '-' ELSE CAST ( (Activity.EndTime - Activity.StartTime) AS INTEGER) END AS [Calculated Duration],
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
