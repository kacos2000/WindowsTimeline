Select
    Activity.ETag as 'Etag',
	datetime(Activity.StartTime, 'unixepoch', 'localtime') as 'StartTime',
   datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModified',
	case 
		when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' 
			then 'Mozilla Firefox-64bit'
			when json_extract(Activity.AppId, '$[0].application') = 'E7CF176E110C211B'
			then 'Mozilla Firefox-32bit'
		when json_extract(Activity.AppId, '$[1].application') = '308046B0AF4A39CB'
			then 'Mozilla Firefox-64bit'
			when json_extract(Activity.AppId, '$[1].application') = 'E7CF176E110C211B'
			then 'Mozilla Firefox-32bit'
		when length (json_extract(Activity.AppId, '$[1].application')) > 17 
			and length (json_extract(Activity.AppId, '$[1].application')) < 22 
			then 
			replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[0].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'), 
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System' ),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
			else    replace(replace(replace(replace(replace(json_extract(Activity.AppId, 
			'$[1].application'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)' ), 
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System' ),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	end as 'Application',


  case when json_extract(Activity.ClipboardPayload, '$[0].formatName') = 'Text' then 
  json_extract(Activity.ClipboardPayload, '$[0].content') else ' ' end as 'Text(Base64)',
  
  Activity.ClipboardPayload as 'ClipboardPayload',
	case Activity.ActivityType 
		when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
		when 10 then 'Clipboard' when 16 then 'Copy/Paste'
		else Activity.ActivityType end as 'Activity_type',
  Activity."Group" as 'Group',
  Activity.GroupAppActivityId as 'GroupAppActivityId',
  Activity.GroupItems as 'GroupItems',
  hex(Activity.ParentActivityId) as 'ParentActivityId',
  Activity.DdsDeviceId as 'DdsDeviceId',
  Activity.PlatformDeviceId as 'Device ID', 
   cast((Activity.ExpirationTime - Activity.LastModifiedTime) as integer) / '86400' as 'Expires In days',

   json_extract(Activity.Payload, '$.clipboardDataId') as 'clipboardDataId',

	case 
		when Activity.OriginalLastModifiedOnClient > 0 
			then datetime(Activity.OriginalLastModifiedOnClient, 'unixepoch', 'localtime') 
			else '  -  ' 
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

   datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration on PackageID',
   datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') as 'Expiration',  
    case Activity.IsLocalOnly when 0 then 'No' when 1 then 'Yes' else Activity.IsLocalOnly end as 'IsLocalOnly',
	   Activity.PackageIdHash as 'PackageIdHash',
		 '{' || substr(hex(Activity_PackageId.ActivityId), 1, 8) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 9, 4) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 13, 4) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 17, 4) || '-' ||
				substr(hex(Activity_PackageId.ActivityId), 21, 12) || '}' as 'ID'

 
from Activity_PackageId
join Activity on Activity_PackageId.ActivityId = Activity.Id  
where 	Activity_PackageId.Platform = json_extract(Activity.AppId, '$[0].platform')
	and Activity_PackageId.ActivityId = Activity.Id and Activity.ActivityType in (10,16)
order by Etag desc;