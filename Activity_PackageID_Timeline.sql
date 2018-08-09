select

case when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation) then 'Both' 
	 when Activity_PackageId.ActivityId  not in (select Activity.Id from activity) and Activity_PackageId.ActivityId  not in 	(select ActivityOperation.Id from ActivityOperation) then 'ActivityPackage_ID'
	 when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId not in 	(select ActivityOperation.Id from ActivityOperation) then 'Activity'
	 when Activity_PackageId.ActivityId not in  (select Activity.Id from Activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation) then 'ActivityOperation'
end as 'Table',
	
case when Activity_PackageId.ActivityId in 	    (select Activity.Id from activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation)  
		then (select case Activity.ActivityStatus when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' end from Activity ) 
	 when Activity_PackageId.ActivityId  not in (select Activity.Id from activity) and Activity_PackageId.ActivityId  not in 	(select ActivityOperation.Id from ActivityOperation)	
		then '' 
	 when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId not in 	(select ActivityOperation.Id from ActivityOperation)
		then (select case Activity.ActivityStatus when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' end from Activity ) 
	 when Activity_PackageId.ActivityId not in 	(select Activity.Id from Activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation) 
		then ''		
end as 'Activity_status',

case when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation)  
		then (select case ActivityOperation.OperationType when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' end from ActivityOperation ) 
	 when Activity_PackageId.ActivityId  not in (select Activity.Id from activity) and Activity_PackageId.ActivityId  not in 	(select ActivityOperation.Id from ActivityOperation)	
		then ''
	 when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId not in 	(select ActivityOperation.Id from ActivityOperation)
		then ''
	when Activity_PackageId.ActivityId not in 	(select Activity.Id from Activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation) 	
		then (select case ActivityOperation.OperationType when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' end from ActivityOperation ) 
end as 'ActivityOperation_status',

	
case when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation) then 'Upload Queue' 
	 when Activity_PackageId.ActivityId  not in (select Activity.Id from activity) and Activity_PackageId.ActivityId  not in 	(select ActivityOperation.Id from ActivityOperation) then 'Archived'
	 when Activity_PackageId.ActivityId in 		(select Activity.Id from activity) and Activity_PackageId.ActivityId not in 	(select ActivityOperation.Id from ActivityOperation) then 'New Activity'
	 when Activity_PackageId.ActivityId not in 	(select Activity.Id from Activity) and Activity_PackageId.ActivityId in 		(select ActivityOperation.Id from ActivityOperation) then 'Removed'
end as 'TileStatus ',
	   
hex(Activity_PackageId.ActivityId) as 'ID', -- unique ID

replace(replace(replace(replace(replace(replace(
			Activity_PackageId.PackageName,
			lower('308046B0AF4A39CB'), 'Mozilla Firefox'),
			'{'||lower('6D809377-6AF0-444B-8957-A3773F02200E')||'}', '*ProgramFiles (x64)'),
			'{'||lower('7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E')||'}', '*ProgramFiles (x32)'),
			'{'||lower('1AC14E77-02E7-4E5D-B744-2EB1AE5198B7')||'}', '*System'),
			'{'||lower('F38BF404-1D43-42F2-9305-67DE0B28FC23')||'}', '*Windows'),
			'{'||lower('D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27')||'}', '*System32') as 'PackageName', -- The program/application associated with the above ID
Activity_PackageId.Platform as 'Platform',  
case when Activity_PackageId.ExpirationTime - strftime('%s','now') -- <= 2592000  
then datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') 
else '-' end as 'ExpirationTime', -- <=  Time when the entry will be removed

case when Activity_PackageId.ExpirationTime - strftime('%s','now') -- <= 2592000  
then datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime', '-1 month') 
else '-' end as 'StartTime' -- <=  Calculated Time when the entry started (1 month earlier than expiry time)


from Activity_PackageId 
where Activity_PackageId.Platform in ('windows_win32', 'windows_universal', 'x_exe_path')
group by ID
order by ExpirationTime desc

