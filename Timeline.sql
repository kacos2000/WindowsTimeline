-- SQLite query to get useful results from MS Windows 1803/1809/1903+ 
-- Timeline feature's database (ActivitiesCache.db).
-- 
-- Dates/Times in the database are stored in Unixepoch and UTC by default. 
-- Using the 'localtime'  converts it to our TimeZone.
-- 
-- The 'Device ID' may be found in the user’s NTUSER.dat at
-- Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\
-- which shows the originating device info.
--
-- The Query uses the SQLite JSON1 extension to parse information from the BLOBs found at 
-- the Activity and ActivityOperation tables. 
--
-- HKLM: \SOFTWARE\Mozilla\Firefox\TaskBarIDs :
-- 308046B0AF4A39CB is Mozilla Firefox 64bit
-- E7CF176E110C211B is Mozilla Firefox 32bit
--
-- Known folder GUIDs 
-- "https://docs.microsoft.com/en-us/dotnet/framework/winforms/controls/known-folder-guids-for-file-dialog-custom-places"
-- 
-- Duration or totalEngagementTime += e.EndTime.Value.Ticks - e.StartTime.Ticks) 
-- https://docs.microsoft.com/en-us/uwp/api/windows.applicationmodel.useractivities
-- 
-- StartTime: The start time for the UserActivity
-- EndTime: The time when the user stopped engaging with the UserActivity  
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2019


SELECT -- This the ActivityOperation Table Query
	ActivityOperation.ETag as 'Etag',
	case 
		when json_extract(ActivityOperation.AppId, '$[0].platform') != "afs_crossplatform"  
	    	then json_extract(ActivityOperation.AppId, '$[0].application') 
		when json_extract(ActivityOperation.AppId, '$[0].application') = '308046B0AF4A39CB' 
			then 'Mozilla Firefox-64bit'
		when json_extract(ActivityOperation.AppId, '$[0].application') = 'E7CF176E110C211B'
			then 'Mozilla Firefox-32bit'
		when json_extract(ActivityOperation.AppId, '$[1].application') = '308046B0AF4A39CB'
			then 'Mozilla Firefox-64bit'
		when json_extract(ActivityOperation.AppId, '$[1].application') = 'E7CF176E110C211B'
			then 'Mozilla Firefox-32bit'
		when length (json_extract(ActivityOperation.AppId, '$[1].application')) between 17 and 22 
			then 
			replace(replace(replace(replace(replace
			(json_extract(ActivityOperation.AppId, '$[0].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles(x64)'), 
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles(x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System' ),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
		else replace(replace(replace(replace(replace(json_extract(ActivityOperation.AppId,'$[1].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles(x64)' ), 
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles(x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System' ),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	end as 'Application',
	case 
		when ActivityOperation.ActivityType = 5 
		then json_extract(ActivityOperation.Payload, '$.appDisplayName') 
		else ''
	end as 'DisplayName',
	case 
		when ActivityOperation.ActivityType = 5
		then json_extract(ActivityOperation.Payload, '$.displayText') 
		else '' 
	end as 'DisplayText',
	case 
		when ActivityOperation.ActivityType = 5  
		then json_extract(ActivityOperation.Payload, '$.description') 
		else ''  
	end as 'Description',
	case 
		when ActivityOperation.ActivityType = 5 
		then json_extract(ActivityOperation.Payload, '$.contenturi') 
		else ''  
	end as 'Content',
	trim(ActivityOperation.AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\')  as 'AppActivityId',
	case 
		when ActivityOperation.ActivityType = 10 and json_extract(ActivityOperation.Payload,'$') notnull
		then json_extract(ActivityOperation.Payload,'$')
		when ActivityOperation.ActivityType in (11,12,15) and ActivityOperation.Payload notnull  
		then ActivityOperation.Payload
		when ActivityOperation.ActivityType = 5 and json_extract(ActivityOperation.Payload, '$.shellContentDescription') like '%FileShellLink%' 
	    then json_extract(ActivityOperation.Payload, '$.shellContentDescription.FileShellLink') 
		when ActivityOperation.ActivityType = 6 
		then json_extract(ActivityOperation.Payload, '$.type')||' - ' ||json_extract(ActivityOperation.Payload,'$.userTimezone')
		else ''	
	end as 'Payload/Timezone',
	case  
		when ActivityOperation.ActivityType = 5 then 'Open App/File/Page('||ActivityOperation.ActivityType||')' 
		when ActivityOperation.ActivityType = 6 then 'App In Use/Focus  ('||ActivityOperation.ActivityType||')'  
		when ActivityOperation.ActivityType = 10 then 'Clipboard ('||ActivityOperation.ActivityType||')'  
		when ActivityOperation.ActivityType = 16 then 'Copy/Paste('||ActivityOperation.ActivityType||')' 
		when ActivityOperation.ActivityType in (11,12,15) then 'System ('||ActivityOperation.ActivityType||')' 
		else ActivityOperation.ActivityType 
	end as 'Activity_type',
	ActivityOperation."Group" as 'Group',
	case 
		when json_extract(ActivityOperation.AppId, '$') like '%afs_crossplatform%' 
		then 'Yes' 
		else 'No' 
		end as 'Synced',	   
	case 
		when json_extract(ActivityOperation.AppId, '$[0].platform') = 'afs_crossplatform' 
		then json_extract(ActivityOperation.AppId, '$[1].platform')
		else json_extract(ActivityOperation.AppId, '$[0].platform') 
	end as 'Platform',
    case ActivityOperation.OperationType 
		when 1 then 'Active' 
		when 2 then 'Updated' 
		when 3 then 'Deleted' 
		when 4 then 'Ignored' 
	end as 'TileStatus',
	'Yes' as 'UploadQueue',
	'' as 'IsLocalOnly',
	ActivityOperation.OperationOrder as 'Order',
	case 
		when ActivityOperation.ActivityType in (11,12,15) 
		then ''
		else coalesce(json_extract(ActivityOperation.Payload, '$.activationUri'),json_extract(ActivityOperation.Payload, '$.reportingApp')) 
	end as 'App/Uri',
   ActivityOperation.Priority as 'Priority',	  
   case 
		when ActivityOperation.ActivityType = 6 and ActivityOperation.Payload notnull
		then time(json_extract(ActivityOperation.Payload, '$.activeDurationSeconds'),'unixepoch')
		else '' 
   end as 'ActiveDuration',
   case 
		when cast((ActivityOperation.EndTime - ActivityOperation.StartTime) as integer) < 0 then '' 
		else time(cast((ActivityOperation.EndTime - ActivityOperation.StartTime) as integer),'unixepoch') 
   end as 'Calculated Duration',
   datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') as 'StartTime', 
   datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModified',
	case 
		when ActivityOperation.OriginalLastModifiedOnClient > 0 
		then datetime(ActivityOperation.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') 
		else '' 
	end as 'LastModifiedOnClient',
	case 
		when ActivityOperation.EndTime > 0 
		then datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') 
		else '' 
	end as 'EndTime',
	case 
		when ActivityOperation.CreatedInCloud > 0 
		then datetime(ActivityOperation.CreatedInCloud, 'unixepoch', 'localtime') 
		else '' 
	end as 'CreatedInCloud',
    case 
		when ActivityOperation.ActivityType = 10 
		then cast((ActivityOperation.ExpirationTime - ActivityOperation.LastModifiedTime)/3600 as integer)||' hours'
		else cast((ActivityOperation.ExpirationTime - ActivityOperation.LastModifiedTime)/86400 as integer)||' days' 
    end as 'ExpiresIn',
   datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration',
   case 
	when ActivityOperation.Tag notnull
	then ActivityOperation.Tag
	else ''
   end as 'Tag',
   ActivityOperation.MatchId as 'MatchID',
   ActivityOperation.PlatformDeviceId as 'Device ID', 
   ActivityOperation.PackageIdHash as 'PackageIdHash',
	 '{' || substr(hex(ActivityOperation.Id), 1, 8) || '-' || 
			substr(hex(ActivityOperation.Id), 9, 4) || '-' || 
			substr(hex(ActivityOperation.Id), 13, 4) || '-' || 
			substr(hex(ActivityOperation.Id), 17, 4) || '-' || 
			substr(hex(ActivityOperation.Id), 21, 12) || '}' as 'ID',
	case 
		when hex(ActivityOperation.ParentActivityId) = '00000000000000000000000000000000'
		then '' else  
		 '{' || substr(hex(ActivityOperation.ParentActivityId), 1, 8) || '-' || 
				substr(hex(ActivityOperation.ParentActivityId), 9, 4) || '-' || 
				substr(hex(ActivityOperation.ParentActivityId), 13, 4) || '-' || 
				substr(hex(ActivityOperation.ParentActivityId), 17, 4) || '-' || 
				substr(hex(ActivityOperation.ParentActivityId), 21, 12) || '}' 
	end as 'ParentActivityId',
	case 
		when ActivityOperation.ActivityType = 16 
		then json_extract(ActivityOperation.Payload, '$.clipboardDataId') 
		else ''
	end as 'ClipboardDataId',		
	case 
		when ActivityOperation.ActivityType = 10 
		then json_extract(ActivityOperation.ClipboardPayload,'$[0].content')
		else ''
	end as 'Clipboard Text(Base64)',	
	case 
		when ActivityOperation.ActivityType = 16 
		then json_extract(ActivityOperation.Payload, '$.gdprType')
		else ''
	end as 'gdpr type',
   ActivityOperation.GroupAppActivityId as 'GroupAppActivityId',
   ActivityOperation.EnterpriseId as 'EnterpriseId',
   case 
		when ActivityOperation.OriginalPayload notnull
		then ActivityOperation.OriginalPayload
		else ''
	end as 'OriginalPayload'

from ActivityOperation
join Activity on ActivityOperation.Id = Activity.Id

union  

select -- This the Activity Table Query
   Activity.ETag as 'Etag',
   case 
		when json_extract(Activity.AppId, '$[0].platform') != "afs_crossplatform"  
		then json_extract(Activity.AppId, '$[0].application') 
	when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' 
	then 'Mozilla Firefox-64bit'
	when json_extract(Activity.AppId, '$[0].application') = 'E7CF176E110C211B'
		then 'Mozilla Firefox-32bit'
	when json_extract(Activity.AppId, '$[1].application') = '308046B0AF4A39CB'
		then 'Mozilla Firefox-64bit'
	when json_extract(Activity.AppId, '$[1].application') = 'E7CF176E110C211B'
		then 'Mozilla Firefox-32bit'
	when length(json_extract(Activity.AppId, '$[1].application')) between 17 and 22 
		then 
		replace(replace(replace(replace(replace
		(json_extract(Activity.AppId, '$[0].application'),
		'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles(x64)'), 
		'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles(x32)'),
		'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System' ),
		'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
		'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	else replace(replace(replace(replace(replace(json_extract(Activity.AppId,'$[1].application'),
		'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles(x64)' ), 
		'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles(x32)'),
		'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System' ),
		'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
		'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32')  
	end as 'Application',
	case 
		when Activity.ActivityType = 5 
		then json_extract(Activity.Payload, '$.appDisplayName') 
		else ''
	end as 'DisplayName',
	case 
			when Activity.ActivityType = 5
			then json_extract(Activity.Payload, '$.displayText') 
			else '' 
	end as 'DisplayText',
	case 
			when Activity.ActivityType = 5 
			then json_extract(Activity.Payload, '$.description') 
			else '' 
	end as 'Description',
	case 
			when Activity.ActivityType =  5 
			then json_extract(Activity.Payload, '$.contentUri') 
			else ''  
	end as 'Content',
	trim(Activity.AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\')  as 'AppActivityId',
	case 
		when Activity.ActivityType = 10 and json_extract(Activity.Payload,'$') notnull
		then json_extract(Activity.Payload,'$')
		when Activity.ActivityType in (11,12,15) and Activity.Payload notnull
		then Activity.Payload
		when Activity.ActivityType = 5 and json_extract(Activity.Payload, '$.shellContentDescription') like '%FileShellLink%' 
	    then json_extract(Activity.Payload, '$.shellContentDescription.FileShellLink') 
		when Activity.ActivityType = 6 
		then json_extract(Activity.Payload, '$.type')||' - ' ||json_extract(Activity.Payload,'$.userTimezone')
		else ''	
	end as 'Payload/Timezone',
	case 
			when Activity.ActivityType = 5 then 'Open App/File/Page('||Activity.ActivityType||')' 
			when Activity.ActivityType = 6 then 'App In Use/Focus  ('||Activity.ActivityType||')' 
			when Activity.ActivityType = 10 then 'Clipboard ('||Activity.ActivityType||')' 
			when Activity.ActivityType = 16 then 'Copy/Paste('||Activity.ActivityType||')'
			when Activity.ActivityType in (11,12,15) then 'System ('||Activity.ActivityType||')'
			else Activity.ActivityType 
	end as 'Activity_type',
	Activity."Group" as 'Group',
	case 
		when json_extract(Activity.AppId, '$') like '%afs_crossplatform%' 
		then 'Yes' 
		else 'No' 
		end as 'Synced',
	case 
		when json_extract(Activity.AppId, '$[0].platform') = 'afs_crossplatform' 
		then json_extract(Activity.AppId, '$[1].platform')
		else json_extract(Activity.AppId, '$[0].platform') 
	end as 'Platform',
    case Activity.ActivityStatus 
		when 1 then 'Active' 
		when 2 then 'Updated' 
		when 3 then 'Deleted' 
		when 4 then 'Ignored' 
	end as 'TileStatus',
    '' as 'UploadQueue',
    case Activity.IsLocalOnly
		when 0 then 'No' 
		when 1 then 'Yes' 
		else Activity.IsLocalOnly 
	end as 'IsLocalOnly',
   '' as 'Order',  
   case 
		when Activity.ActivityType in (11,12,15) 
		then ''
		else  coalesce(json_extract(Activity.Payload, '$.activationUri'),json_extract(Activity.Payload, '$.reportingApp')) 
		end as 'App/Uri',
    Activity.Priority as 'Priority',	  
    case 
		when Activity.ActivityType = 6 and Activity.Payload notnull
		then time(json_extract(Activity.Payload, '$.activeDurationSeconds'),'unixepoch')
		else '' 
    end as 'ActiveDuration',
    case 
		when cast ((Activity.EndTime - Activity.StartTime) as integer) < 0 
		then '' 
		else time(cast((Activity.EndTime - Activity.StartTime) as integer),'unixepoch') 
	end as 'Calculated Duration',
    datetime(Activity.StartTime, 'unixepoch', 'localtime') as 'StartTime',
    datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModified',
	case 
		when Activity.OriginalLastModifiedOnClient > 0 
		then datetime(Activity.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') 
		else '' 
	end as 'LastModifiedOnClient',
	case 
		when Activity.EndTime > 0 
		then datetime(Activity.EndTime, 'unixepoch', 'localtime') 
		else '' 
	end as 'EndTime',
	case 
		when Activity.CreatedInCloud > 0 
		then datetime(Activity.CreatedInCloud, 'unixepoch', 'localtime') 
		else '' 
	end as 'CreatedInCloud',
   case 
		when Activity.ActivityType = 10 
		then cast((Activity.ExpirationTime - Activity.LastModifiedTime)/3600 as integer)||' hours'
		else cast((Activity.ExpirationTime - Activity.LastModifiedTime)/86400 as integer)||' days' 
   end as 'Expires In',
    datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration',
    case 
		when Activity.Tag notnull
		then Activity.Tag
		else ''
	end as 'Tag',
    Activity.MatchId as 'MatchID',
    Activity.PlatformDeviceId as 'Device ID', 
    Activity.PackageIdHash as 'PackageIdHash',
		 '{' || substr(hex(Activity.Id), 1, 8) || '-' ||
				substr(hex(Activity.Id), 9, 4) || '-' ||
				substr(hex(Activity.Id), 13, 4) || '-' ||
				substr(hex(Activity.Id), 17, 4) || '-' ||
				substr(hex(Activity.Id), 21, 12) || '}' as 'ID',
    case 
		when hex(Activity.ParentActivityId) = '00000000000000000000000000000000'
		then '' 
		else  
		 '{' || substr(hex(Activity.ParentActivityId), 1, 8) || '-' || 
				substr(hex(Activity.ParentActivityId), 9, 4) || '-' || 
				substr(hex(Activity.ParentActivityId), 13, 4) || '-' || 
				substr(hex(Activity.ParentActivityId), 17, 4) || '-' || 
				substr(hex(Activity.ParentActivityId), 21, 12) || '}' 
	end as 'ParentActivityId',
	case 
		when Activity.ActivityType = 16 
		then json_extract(Activity.Payload, '$.clipboardDataId') 
		else ''
	end as 'ClipboardDataId',
    case 
		when Activity.ActivityType = 10 
		then json_extract(Activity.ClipboardPayload,'$[0].content')
		else ''
	end as 'Clipboard Text(Base64)',
	  case 
	when Activity.ActivityType = 16 
	then json_extract(Activity.Payload, '$.gdprType')
	else ''
  end as 'gdpr type',
    Activity.GroupAppActivityId as 'GroupAppActivityId',
    Activity.EnterpriseId as 'EnterpriseId',
  case 
		when Activity.OriginalPayload notnull
		then Activity.OriginalPayload
		else ''
	end as 'OriginalPayload'

from Activity   
where  Activity.Id not in (select ActivityOperation.Id from ActivityOperation)

order by Etag desc;  -- Edit this line to change the sorting 
 
-- EOF