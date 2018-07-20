#Requires -RunAsAdministrator

# Requires SQLite3.exe 
# Instructions (http://www.sqlitetutorial.net/download-install-sqlite/)
# SQLite3.exe (https://www.sqlite.org/2018/sqlite-tools-win32-x86-3240000.zip) with
# 32bit Dll (https://www.sqlite.org/2018/sqlite-dll-win32-x86-3240000.zip) or the
# 64bit Dll (https://www.sqlite.org/2018/sqlite-dll-win64-x64-3240000.zip)
# Note - After you install the latest SQLite3.exe, check the version from inside powershell
# by running SQLite3.exe -version (you may have already an older version in your Path)


# Device Name and Model of the originating machine can be seen 
# in the HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\

# Note:
# Device Name and Model of the originating machine can be seen 
# in the HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\



# Show an Open File Dialog 
Function Get-FileName($initialDirectory)
{  
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |Out-Null
		$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
		$OpenFileDialog.Title = 'Select ActivitiesCache.db database to access'
		$OpenFileDialog.initialDirectory = $initialDirectory
		$OpenFileDialog.Filter = "ActivitiesCache.db (*.db)|ActivitiesCache.db"
		$OpenFileDialog.ShowDialog() | Out-Null
		$OpenFileDialog.ShowReadOnly = $true
		$OpenFileDialog.filename
		$OpenFileDialog.ShowHelp = $false
} #end function Get-FileName 

$dBPath =  $env:LOCALAPPDATA+"\ConnectedDevicesPlatform\"
$File = Get-FileName -initialDirectory $dBPath
$F =$File.replace($env:LOCALAPPDATA,'')
# Run SQLite query of the Selected dB
# The Query (between " " below)
# can also be copy/pasted and run on 'DB Browser for SQLite' 

Try{(Get-Item $File).FullName}
Catch{Write-Host "(WinTimelineLocal.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White; exit}
 

$db = $File
$sw = [Diagnostics.Stopwatch]::StartNew()
$sw1 = [Diagnostics.Stopwatch]::StartNew()

$Query = @"
select 
       ActivityOperation.ETag,
       ActivityOperation.AppId, 
       case ActivityOperation.ActivityType when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
	   else 'Unknown yet' end as 'ActivityType', 
       case ActivityOperation.OperationType 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus',
        'Yes' AS 'IsInUploadQueue', 
       datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModifiedTime',
       datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime')as 'ExpirationTime',
       datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') as 'EndTime',
       ActivityOperation.Payload, 
       ActivityOperation.PlatformDeviceId 
       
from   ActivityOperation 
       left outer join Activity on ActivityOperation.Id = Activity.Id
union
select 
       Activity.ETag,
       Activity.AppId, 
       case Activity.ActivityType when 5 then 'Open App/File/Page' when 6 then 'App In Use/Focus' 
	   else 'Unknown yet' end as 'ActivityType', 
       case Activity.ActivityStatus 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus',
       'No' AS 'IsInUploadQueue', 
       datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime')as 'LastModifiedTime',
       datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') as 'ExpirationTime',
       datetime(Activity.StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(Activity.EndTime, 'unixepoch', 'localtime') as 'EndTime',
       Activity.Payload, 
       Activity.PlatformDeviceId 
       
from   Activity
where  Activity.Id not in (select ActivityOperation.Id from ActivityOperation)
order by Etag desc
"@ 
write-progress -id 1 -activity "Running SQLite query (Might take a few minutes if dB is large)" 

$dbresults = @(sqlite3.exe $db $query|ConvertFrom-String -Delimiter '\u007C' -PropertyNames ETag, AppId, ActivityType, ActivityStatus, IsInUploadQueue, LastModifiedTime, ExpirationTime, StartTime, EndTime, Payload, PlatformDeviceId)
$dbcount = $Database.count
$sw.stop()
$T0 = $sw1.Elapsed.TotalMinutes
write-progress -id 1 -activity "Running SQLite query" -status "Query Finished in $T0 minutes" 

#Query HKCU, check results against the Database 
$Registry = [pscustomobject]@()
$DeviceID =  (Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\" -name)|Select-Object 
$UserBias = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\TimeZoneInformation").ActiveTimeBias
$UserDay = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\TimeZoneInformation").DaylightBias
			$Bias = -([convert]::ToInt32([Convert]::ToString($UserBias,2),2))
			$Day = -([convert]::ToInt32([Convert]::ToString($UserDay,2),2)) 
			$Biasd = $Bias/60
$RegCount =$DeviceID.count
$ra=0
$rb=0

$Registry = foreach ($entry in $DeviceID){$ra++
            $dpath = join-path -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\" -childpath $entry
            Write-Progress -id 2 -Activity "Getting Entries" -Status "HKCU Entry $ra of $($RegCount))" -PercentComplete (([double]$ra / $RegCount)*100) -ParentID 1
                $ID = $entry
                $Type = (get-itemproperty -path $dpath).DeviceType
                $Name = (get-itemproperty -path $dpath).DeviceName
                $Make = (get-itemproperty -path $dpath).DeviceMake
                $Model= (get-itemproperty -path $dpath).DeviceModel 
                [PSCustomObject]@{
                                ID = $ID
                                Type = $Type
                                Name = $Name
                                Make = $Make
                                Model = $Model
                     }
            }        

     
  $Output = foreach ($item in $dbresults ){$rb++
                    Write-Progress -id 3 -Activity "Creating Output" -Status "Combining Database - $rb of $($dbresults.count))" -PercentComplete (([double]$rb / $dbresults.count)*100) -ParentID 1
                    $rc=0
                    foreach ($rin in $Registry){$rc++
                    
                    Write-Progress -id 4 -Activity "Creating Output" -Status "with matching Registry entries - $rc of $($Registry.count))" -PercentComplete (([double]$rc / $Registry.count)*100) -ParentID 1
                    if($item.PlatformDeviceId -eq $rin.ID){
                    
                    $platform = ($item.Appid|convertfrom-json).platform
                    $app = if (($item.Appid|convertfrom-json).platform -eq "x_exe"){($item.Appid|convertfrom-json).application}
		    elseif (($item.Appid|convertfrom-json).platform -eq "windows_win32"){($item.Appid|convertfrom-json).application}
		    elseif (($item.Appid|convertfrom-json).platform -eq "windows_universal"){($item.Appid|convertfrom-json).application}
                    $app = if($platform = 'windows_win32'){$app = $application} elseif ($platform = 'x_exe_path'){$app = $application} 
                    $type = ($item.Payload |ConvertFrom-Json).Type
                    $Duration = ($item.Payload |ConvertFrom-Json).activeDurationSeconds
                    $displayText = ($item.Payload |ConvertFrom-Json).displayText
                    $description = ($item.Payload |ConvertFrom-Json).description
                    $displayname = ($item.Payload |ConvertFrom-Json).appDisplayName
                    $content = ($item.Payload |ConvertFrom-Json).contentUri
                                                    
                    [PSCustomObject]@{
                                ETag = $item.ETag 
                                App_name = $app
                                DisplayText = $displayText
                                Description = $description
                                DisplayName = $displayname
                                Content = $content
                                Type = $type
                                ActivityType = $item.ActivityType 
                                ActivityStatus = $item.ActivityStatus
                                IsInUploadQueue = $item.IsInUploadQueue
                                Duration = $Duration
                                LastModifiedTime = $item.LastModifiedTime
                                ExpirationTime = $item.ExpirationTime
                                StartTime = $item.StartTime
                                EndTime = $item.EndTime
                                PlatformDeviceId = $item.PlatformDeviceId 
                                'Type#' = if($rin.Type -eq 15){"Laptop"}elseif($rin.Type -eq 9){"Desktop PC"}else{$rin.Type}
                                Name = $rin.Name
                                Make = $rin.Make
                                Model = $rin.Model
                                }
                        }                              
              }
}
$sw1.stop()           
$T = $sw1.Elapsed.TotalMinutes

$Output|Out-GridView -PassThru -Title "Windows Timeline - ActiveBias= $Biasd - Done in $T minutes"           



