-- Query of ActivitiesCache.db 
-- where the actual status of each entry is shown as:
-- 'New Activity'
-- 'Tile Removed'
-- 'In Upload Queue'
-- 'Is Archived' (until expiration time)
-- and sorted by Expiration Time
--
-- Costas Katsavounidis (kacos2000 [at] gmail.com)
-- May 2018

select

case -- Note: the letters A, O or P denote the Database Table (Activity, ActivityOperation or Activity_PackageId)

	when 
		Activity_PackageId.ActivityId in (select Activity.Id from activity) and
		Activity_PackageId.ActivityId in (select ActivityOperation.Id from ActivityOperation)   
	then 'O '||(select case Activity.ActivityStatus when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end from Activity )||','||(select case ActivityOperation.OperationType 
			when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
			end from ActivityOperation)||'-'||'Tile Removed'
	else 
		case when 	Activity_PackageId.ActivityId  not in (select Activity.Id from activity) and
					Activity_PackageId.ActivityId  not in (select ActivityOperation.Id from ActivityOperation)
			 then 'P  - - Is Archived'
			 else 
				case 	when Activity_PackageId.ActivityId in (select Activity.Id from activity) and
						     Activity_PackageId.ActivityId not in (select ActivityOperation.Id from ActivityOperation)
						then 'A  '||(select case Activity.ActivityStatus when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
							end from Activity where Activity_PackageId.ActivityId = Activity.id)||'- '||'New Activity'
						else 
						case 	when 	Activity_PackageId.ActivityId not in (select Activity.Id from Activity) and
										Activity_PackageId.ActivityId in (select ActivityOperation.Id from ActivityOperation)
								then 'O  '||(select case ActivityOperation.OperationType 
									when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
									end from ActivityOperation where Activity_PackageId.ActivityId = ActivityOperation.id)||'- '||'Upload Queue'
				end
		end
	end
end as 'ActivityType_TileStatus', -- This field includes both the Status and Operation Type of the associated activity

hex(Activity_PackageId.ActivityId) as 'ID', -- unique ID

replace(replace(replace(replace(replace(replace(
			Activity_PackageId.PackageName,
			lower('308046B0AF4A39CB'), 'Mozilla Firefox'),
			'{'||lower('6D809377-6AF0-444B-8957-A3773F02200E')||'}', '*ProgramFiles (x64)'),
			'{'||lower('7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E')||'}', '*ProgramFiles (x32)'),
			'{'||lower('1AC14E77-02E7-4E5D-B744-2EB1AE5198B7')||'}', '*System'),
			'{'||lower('F38BF404-1D43-42F2-9305-67DE0B28FC23')||'}', '*Windows'),
			'{'||lower('D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27')||'}', '*System32') as 'PackageName', -- The program/application associated with the above ID

case when Activity_PackageId.ExpirationTime - strftime('%s','now') <= 2592000  
then datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') 
else '-' end as 'ExpirationTime', 
Activity_PackageId.Platform  

from Activity_PackageId 
where Activity_PackageId.Platform in ('windows_win32', 'windows_universal', 'x_exe_path')
group by ID
order by ExpirationTime desc

-- EOF