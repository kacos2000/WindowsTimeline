-- SQLite query to get any useful results from MS Windows 1803 Timeline feature's database (ActivitiesCache.db).
-- Dates/Times in the database are stored in Unixepoch and UTC by default. 
-- Using the 'localtime"  converts it to our TimeZone.
-- The 'DeviceID' may be found in the user’s NTUSER.dat at
-- Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\
-- 
-- The Query uses the SQLite JSON1 extension to parse information from the BLOBs found at 
-- the Activity and ActivityOperation tables. 
--
-- 308046B0AF4A39CB is Firefox as seen at 'SOFTWARE\RegisteredApplications'
--
-- Known folder GUIDs 
-- "https://docs.microsoft.com/en-us/dotnet/framework/winforms/controls/known-folder-guids-for-file-dialog-custom-places"
--
-- Any Entries removed from the Timeline are copied from the Activity table to the ActivityOperation table until
-- they either expire or are uploaded to the Cloud.
-- Any ActivityOperation table's IDs that also exist in the Activity table are marked as Removed. 
-- Also, according to the Smartlookup view, all entries in the Activity Table are marked as NOT in the 
-- upload queue (The UserActivity has not yet been published), 
-- but all entries in the ActivityOperation table minus the ones listed as 'Deleted') are marked 
-- as in the upload queue (The UserActivity has been published on this (or another) device).
-- https://docs.microsoft.com/en-us/uwp/api/windows.applicationmodel.useractivities.useractivitystate 
-- 
-- Duration or totalEngagementTime += e.EndTime.Value.Ticks - e.StartTime.Ticks) 
-- https://docs.microsoft.com/en-us/uwp/api/windows.applicationmodel.useractivities
-- 
-- StartTime: The start time for the UserActivity
-- EndTime: The time when the user stopped engaging with the UserActivity  
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2018


SELECT -- This the ActivityOperation Table Query
	ActivityOperation.ETag as 'Etag', 
	json_extract(ActivityOperation.Payload, '$.appDisplayName') as 'Program Name',
	case 
		when json_extract(ActivityOperation.AppId, '$[0].application') = '308046B0AF4A39CB' 
			then 'Firefox-308046B0AF4A39CB'
		when json_extract(ActivityOperation.AppId, '$[1].application') = '308046B0AF4A39CB' 
			then 'Firefox-308046B0AF4A39CB'
		when length (json_extract(ActivityOperation.AppId, '$[1].application')) > 17 
			and length (json_extract(ActivityOperation.AppId, '$[1].application')) < 22 
			then 
			replace(replace(replace(replace(replace
			(json_extract(ActivityOperation.AppId, '$[0].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * '), 
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
			else    replace(replace(replace(replace(replace(json_extract(ActivityOperation.AppId, 
			'$[1].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ), 
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ) ,
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
	end as Application,
   json_extract(ActivityOperation.Payload, '$.displayText') as 'File/title opened',
   json_extract(ActivityOperation.Payload, '$.description') as 'Full Path /Url',
   json_extract(ActivityOperation.Payload, '$.activationUri') as 'AppUriHandler',
   json_extract(ActivityOperation.Payload, '$.shellContentDescription') as 'FileShellLink (json)',
	case json_extract(ActivityOperation.AppId, '$[0].platform') 
		when 'afs_crossplatform' then 'Yes' 
		when 'host' then 
			(case json_extract(ActivityOperation.AppId, '$[1].platform') 
			when 'afs_crossplatform' then 'Yes' else null end) 
		else null 
	end as 'Synced',	   
	case 
		when json_extract(ActivityOperation.AppId, '$[0].platform') = 'afs_crossplatform' 
			then json_extract(ActivityOperation.AppId, '$[1].platform')
		else json_extract(ActivityOperation.AppId, '$[0].platform') 
	end as 'Platform_id',
   ActivityOperation.PackageIdHash as 'Hash',
   case ActivityOperation.OperationType 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
	end as 'TileStatus',
    case 
		when ActivityOperation.Id in
			(select Activity.Id from Activity where Activity.Id = ActivityOperation.Id) 
			then 'Removed' 
	end as 'WasRemoved',
	case 
		when ActivityOperation.Id 
			in(select Activity.Id from Activity where Activity.Id = ActivityOperation.Id) 
			then null else 'In Queue' 
	end as 'UploadQueue',
	case ActivityOperation.ActivityType 
		when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
		else 'Unknown yet' 
	end as 'Activity_type',
   ActivityOperation.PlatformDeviceId as 'Device ID', 
   json_extract(ActivityOperation.OriginalPayload, '$.type') as 'Type',
   json_extract(ActivityOperation.OriginalPayload, '$.appDisplayName') as 'Original Displayed Name',
   json_extract(ActivityOperation.OriginalPayload, '$.displayText') as 'Original File/title opened',
   json_extract(ActivityOperation.OriginalPayload, '$.description') as 'Original Full Path /Url', 
   json_extract(ActivityOperation.OriginalPayload, '$.activationUri') as 'Original AppUriHandler',
   time(json_extract(ActivityOperation.Payload, '$.activeDurationSeconds'),'unixepoch') as 'Active Duration',
   time(json_extract(ActivityOperation.OriginalPayload, '$.activeDurationSeconds'),'unixepoch') as 'Orig.Duration',
   case 
		when cast((ActivityOperation.EndTime - ActivityOperation.StartTime) as integer) < 0 then '-' 
		else time(cast((ActivityOperation.EndTime - ActivityOperation.StartTime) as integer),'unixepoch') 
   end as 'Calculated Duration',
   datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') as 'StartTime', 
   datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModified',
	case 
		when ActivityOperation.OriginalLastModifiedOnClient > 0 
			then datetime(ActivityOperation.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') 
			else '  -  ' 
	end as 'LastModifiedOnClient',
	case 
		when ActivityOperation.EndTime > 0 
			then datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') 
			else null 
	end as 'EndTime',
	case 
		when ActivityOperation.CreatedInCloud > 0 
			then datetime(ActivityOperation.CreatedInCloud, 'unixepoch', 'localtime') 
			else null 
	end as 'CreatedInCloud',
   json_extract(ActivityOperation.OriginalPayload, '$.userTimezone') as 'TZone',
   cast((ActivityOperation.ExpirationTime - ActivityOperation.LastModifiedTime) 
	as integer) / '86400' as 'Expires In days',
   datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration on PackageID',
   datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration',
	 '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' || 
			substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' || 
			substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' || 
			substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' || 
   substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' as 'ID'

from Activity_PackageId
join ActivityOperation on Activity_PackageId.ActivityId = ActivityOperation.Id  
where 	Activity_PackageId.Platform = json_extract(ActivityOperation.AppId, '$[0].platform') 
	and Activity_PackageId.ActivityId = ActivityOperation.Id

union  -- Join Activity & ActivityOperation Queries to get results from both Tables

select -- This the Activity Table Query
   Activity.ETag as 'Etag',  
   json_extract(Activity.Payload, '$.appDisplayName') AS 'Program Name',
	case 
		when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' 
			then 'Firefox-308046B0AF4A39CB'
		when json_extract(Activity.AppId, '$[1].application') = '308046B0AF4A39CB' 
			then 'Firefox-308046B0AF4A39CB'
		when length (json_extract(Activity.AppId, '$[0].application')) > 17 and 
				length(json_extract(Activity.AppId, '$[0].application')) < 22 
			then replace(replace(replace(replace(replace(json_extract(Activity.AppId, '$[1].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * ' ),  
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * ' ),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
	   when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' 
			then 'Firefox-308046B0AF4A39CB'
			else  replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[0].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '* ProgramFilesX64 * '),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '* ProgramFilesX32 * '),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '* System * '),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '* Windows * '),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '* SystemX86 * ') 
	end as 'Application',
   json_extract(Activity.Payload, '$.displayText') as 'File/title opened',
   json_extract(Activity.Payload, '$.description') as 'Full Path /Url',
   json_extract(Activity.Payload, '$.activationUri') as 'AppUriHandler',
   json_extract(Activity.Payload, '$.shellContentDescription') as 'FileShellLink (json)',
	case json_extract(Activity.AppId, '$[0].platform') 
		when 'afs_crossplatform' then 'Yes' 
		when 'host' then (case json_extract(Activity.AppId, '$[1].platform') 
		when 'afs_crossplatform' then'Yes' else null end) else null 
	end as 'Synced',
	case 
		when json_extract(Activity.AppId, '$[0].platform') = 'afs_crossplatform' 
		then json_extract(Activity.AppId, '$[1].platform')
		else json_extract(Activity.AppId, '$[0].platform') 
	end as 'Platform_id',
   Activity.PackageIdHash as 'Hash',
   case Activity.ActivityStatus 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
	end as 'TileStatus',
   null as 'WasRemoved',
   'No' as 'UploadQueue',  
	case Activity.ActivityType 
		when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
		else 'Unknown yet' 
	end as 'Activity_type',
   Activity.PlatformDeviceId as 'Device ID', 
   json_extract(Activity.OriginalPayload, '$.type') as 'Type',
   json_extract(Activity.OriginalPayload, '$.appDisplayName') as 'Original Program Name',
   json_extract(Activity.OriginalPayload, '$.displayText') as 'Original File/title opened',
   json_extract(Activity.OriginalPayload, '$.description') as 'Original Full Path /Url',
   json_extract(Activity.OriginalPayload, '$.activationUri') as 'Original AppUriHandler',
   time(json_extract(Activity.Payload, '$.activeDurationSeconds'),'unixepoch') as 'Active Duration',
   time(json_extract(Activity.OriginalPayload, '$.activeDurationSeconds'),'unixepoch' ) as 'Orig.Duration',       
	case 
		when cast ((Activity.EndTime - Activity.StartTime) as integer) < 0 then '-' 
		else time(cast((Activity.EndTime - Activity.StartTime) as integer),'unixepoch') 
	end as 'Calculated Duration',
   datetime(Activity.StartTime, 'unixepoch', 'localtime') as 'StartTime',
   datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModified',
	case 
		when Activity.OriginalLastModifiedOnClient > 0 
			THEN datetime(Activity.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') 
			ELSE '  -  ' 
	end as 'LastModifiedOnClient',
	case 
		when Activity.EndTime > 0 
			then datetime(Activity.EndTime, 'unixepoch', 'localtime') 
		else "-" 
	end as 'EndTime',
	case 
		when Activity.CreatedInCloud > 0 
			then datetime(Activity.CreatedInCloud, 'unixepoch', 'localtime') 
			else "-" 
	end as 'CreatedInCloud',
	json_extract(Activity.OriginalPayload, '$.userTimezone') as 'TZone',
   cast((Activity.ExpirationTime - Activity.LastModifiedTime) as integer) / '86400' as 'Expires In days',
   datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration on PackageID',
   datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration',
		 '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' as 'ID'
from Activity_PackageId
join Activity on Activity_PackageId.ActivityId = Activity.Id  
where 	Activity_PackageId.Platform = json_extract(Activity.AppId, '$[0].platform')
	and Activity_PackageId.ActivityId = Activity.Id

order by Etag desc;  -- Edit this line to change the sorting 
 
-- EOF