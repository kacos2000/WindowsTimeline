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


# Show Open File Dialogs 
Function Get-FileName($initialDirectory, $Title ,$Filter)
{  
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |Out-Null
		$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
		$OpenFileDialog.Title = $Title
		$OpenFileDialog.initialDirectory = $initialDirectory
        $OpenFileDialog.Filter = $filter
		$OpenFileDialog.ShowDialog() | Out-Null
		$OpenFileDialog.ShowReadOnly = $true
		$OpenFileDialog.filename
		$OpenFileDialog.ShowHelp = $false
} #end function Get-FileName 

#File 1 is the ActivitiesCache.db ("c:\users\USER\AppData\Local\ConnectedDevicesPlatform\")
$DesktopPath =  [Environment]::GetFolderPath("Desktop")
$File1 = Get-FileName -initialDirectory $DesktopPath -Filter "ActivitiesCache.db (*.db)|ActivitiesCache.db" -Title 'Select ActivitiesCache.db database to access'
$F =$File1.replace($env:LOCALAPPDATA,'')

Write-Host "Loaded ($File1)"

# FIle2 is the NTUSER.dat of the user related to the above Database
$File2 = Get-FileName -initialDirectory $DesktopPath -Filter "NTUser.dat (*.dat)|NTUser.dat" -Title 'Select NTuser.dat'
Write-Host "Loaded ($File2)"  

Try{$before = (Get-FileHash $File2 -Algorithm SHA256).Hash}
Catch{
        Write-Host "(WinTimelineOffline.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White
		[gc]::Collect()		
		reg unload HKEY_LOCAL_MACHINE\Temp 
		exit
} 
write-host "SHA256 Hash of ($File2) before access = " -f magenta -nonewline;write-host "($before)" -f Yellow

#Load NTUSER.dat into a Temp subfolder in HKLM
reg load HKEY_LOCAL_MACHINE\Temp $File2
$ErrorActionPreference = "Stop"

try{$Key = (Get-ItemProperty -Path "HKLM:\Temp\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\")
Write-Host -ForegroundColor Green "File loaded OK"}
Catch{
	Write-Host -ForegroundColor Yellow "The selectd ($File2) does not have the" 
	Write-Host -ForegroundColor Yellow "'Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache' registry key." 
	[gc]::Collect()		
	reg unload HKEY_LOCAL_MACHINE\Temp 
    exit}
finally{
    }
#End of File Selection

	
# Run SQLite query of the Selected dB
# The Query (between " " below)
# can also be copy/pasted and run on 'DB Browser for SQLite' 

Try{(Get-Item $File1).FullName}
Catch{Write-Host "(WinTimelineOffline.ps1.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White; 
		}

#Timers 
$sw = [Diagnostics.Stopwatch]::StartNew()
$sw1 = [Diagnostics.Stopwatch]::StartNew()

#Database Query
$db = $File1
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


#Run of the above query with SQLlite3 
write-progress -id 1 -activity "Running SQLite query (Might take a few minutes if dB is large)" 
$dbresults = @(sqlite3.exe $db $query|ConvertFrom-String -Delimiter '\u007C' -PropertyNames ETag, AppId, ActivityType, ActivityStatus, IsInUploadQueue, LastModifiedTime, ExpirationTime, StartTime, EndTime, Payload, PlatformDeviceId)
$dbcount = $Database.count

#Stop Timer 1
$sw.stop()
$T0 = $sw1.Elapsed.TotalMinutes
write-progress -id 1 -activity "Running SQLite query" -status "Query Finished in $T0 minutes" 

#Query HKCU, check results against the Database 
$Registry = [pscustomobject]@()
$DeviceID =  (Get-ChildItem -Path "HKLM:\Temp\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\" -name)|Select-Object 
$RegCount =$DeviceID.count
$ra=0
$rb=0

$Registry = foreach ($entry in $DeviceID){$ra++
            $dpath = join-path -path "HKLM:\Temp\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\" -childpath $entry
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

                                
                    [PSCustomObject]@{
                                ETag = $item.ETag 
                                AppId = $item.AppId 
                                ActivityType = $item.ActivityType 
                                ActivityStatus = $item.ActivityStatus
                                IsInUploadQueue = $item.IsInUploadQueue
                                LastModifiedTime = $item.LastModifiedTime
                                ExpirationTime = $item.ExpirationTime
                                StartTime = $item.StartTime
                                EndTime = $item.EndTime
                                Payload = $item.Payload
                                PlatformDeviceId = $item.PlatformDeviceId 
                                Type = $rin.Type
                                Name = $rin.Name
                                Make = $rin.Make
                                Model = $rin.Model
                                }
                        }                              
              }
}
#Stop Timer2
$sw1.stop()           
$T = $sw1.Elapsed.TotalMinutes           
     
# Display results 
$Output|Out-GridView -PassThru -Title "Windows Timeline $File1 with Device Information from $File2 - Finished in $T minutes"


[gc]::Collect()		
reg unload HKEY_LOCAL_MACHINE\Temp 
$after = (Get-FileHash $File2 -Algorithm SHA256).Hash 
write-host "SHA256 Hash of ($File2) before access = " -f magenta -nonewline;write-host "($before)" -f Yellow
$result = (compare-object -ReferenceObject $before -DifferenceObject $after -IncludeEqual).SideIndicator 
write-host "The before and after Hashes of ($File2) are ($result) `n `n " -ForegroundColor White
