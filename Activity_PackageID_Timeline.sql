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
case 
	when 
		Activity_PackageId.ActivityId in (select Activity.Id from activity) and
		Activity_PackageId.ActivityId in (select ActivityOperation.Id from ActivityOperation)
	then 'Tile Removed - '||hex(Activity_PackageId.ActivityId)
	else 
		case when 	Activity_PackageId.ActivityId  not in (select Activity.Id from activity) and
					Activity_PackageId.ActivityId  not in (select ActivityOperation.Id from ActivityOperation)
			 then 'Is Archived - '||hex(Activity_PackageId.ActivityId) 
			 else 
				case 	when Activity_PackageId.ActivityId in (select Activity.Id from activity) and
						     Activity_PackageId.ActivityId not in (select ActivityOperation.Id from ActivityOperation)
						then 'New Activity - '||hex(Activity_PackageId.ActivityId)
						else 
						case 	when 	Activity_PackageId.ActivityId not in (select Activity.Id from Activity) and
										Activity_PackageId.ActivityId in (select ActivityOperation.Id from ActivityOperation)
								then 'In Upload Queue - '||hex(Activity_PackageId.ActivityId)
				end
		end
	end
end as 'Status_ID', -- This field includes both the Status and the unique ID of the associated activity
Activity_PackageId.PackageName as 'PackageName', -- The program/application associated with the above ID
datetime(Activity_PackageId.ExpirationTime, 'unixepoch', 'localtime') as 'ExpirationTime', 
Activity_PackageId.Platform  


from Activity_PackageId 

where Activity_PackageId.Platform in ('windows_win32', 'windows_universal', 'x_exe_path')
group by Status_ID
order by ExpirationTime asc

-- EOF