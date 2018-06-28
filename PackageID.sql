select
Activity.ETag,

hex(Activity_PackageId.ActivityId) as 'ID',

replace(replace(replace(replace(replace(replace(
			Activity_PackageId.PackageName,
			lower('308046B0AF4A39CB'), 'Mozilla Firefox'),
			'{'||lower('6D809377-6AF0-444B-8957-A3773F02200E')||'}', '*ProgramFiles (x64)'),
			'{'||lower('7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E')||'}', '*ProgramFiles (x32)'),
			'{'||lower('1AC14E77-02E7-4E5D-B744-2EB1AE5198B7')||'}', '*System'),
			'{'||lower('F38BF404-1D43-42F2-9305-67DE0B28FC23')||'}', '*Windows'),
			'{'||lower('D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27')||'}', '*System32') as 'Activity_PackageId.PackageName',
			
case 
	when json_extract(Activity.AppId, '$[0].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[0].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32')
	when json_extract(Activity.AppId, '$[1].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[1].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	when json_extract(Activity.AppId, '$[2].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[2].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32')  
	when json_extract(Activity.AppId, '$[3].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[3].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	when json_extract(Activity.AppId, '$[4].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[4].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	when json_extract(Activity.AppId, '$[5].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[5].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	when json_extract(Activity.AppId, '$[6].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[6].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	when json_extract(Activity.AppId, '$[7].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[7].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') 
	when json_extract(Activity.AppId, '$[8].platform') like '%packageid%' then replace(replace(replace(replace(replace(replace
			(json_extract(Activity.AppId, '$[8].application'),
			'308046B0AF4A39CB', 'Mozilla Firefox'),
			'{'||'6D809377-6AF0-444B-8957-A3773F02200E'||'}', '*ProgramFiles (x64)'),
			'{'||'7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E'||'}', '*ProgramFiles (x32)'),
			'{'||'1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'||'}', '*System'),
			'{'||'F38BF404-1D43-42F2-9305-67DE0B28FC23'||'}', '*Windows'),
			'{'||'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27'||'}', '*System32') end as 'Activity_json_Packageid'
		
from Activity_PackageId
join Activity on  Activity.Id	= Activity_PackageId.ActivityId
where Activity_PackageId.ActivityId = Activity.Id and Activity_PackageId.Platform = 'packageid'
Order by etag desc