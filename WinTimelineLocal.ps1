#Requires -RunAsAdministrator

#Set encoding to UTF-8 
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = (New-Object System.Text.UTF8Encoding)

#Check if SQLite exists
try{write-host "sqlite3.exe version => "-f Yellow -nonewline; sqlite3.exe -version }
catch {
    write-host "It seems that you do not have sqlite3.exe in the system path"
    write-host "Please read below`n" -f Yellow
    write-host "Install SQLite On Windows:`n

        Go to SQLite download page, and download precompiled binaries from Windows section.
        Instructions: http://www.sqlitetutorial.net/download-install-sqlite/
        Create a folder C:\sqlite and unzip above two zipped files in this folder which will give you sqlite3.def, sqlite3.dll and sqlite3.exe files.
        Add C:\sqlite to the system PATH (https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/)" -f White

    exit}

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

Try{write-host "Selected: " (Get-Item $File)|out-null}
Catch{Write-warning "(WinTimelineLocal.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White; exit}
 

$db = $File
$sw = [Diagnostics.Stopwatch]::StartNew()
$sw1 = [Diagnostics.Stopwatch]::StartNew()

$Query = @"
select 
       ActivityOperation.ETag,
       ActivityOperation.AppId, 
	   case when ActivityOperation.AppActivityId not like '%-%-%-%-%' then ActivityOperation.AppActivityId
		else trim(ActivityOperation.AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\') end as 'AppActivityId',
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
	   case when Activity.AppActivityId not like '%-%-%-%-%' then Activity.AppActivityId
		else trim(Activity.AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\') end as 'AppActivityId',
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

$dbresults = @(sqlite3.exe -readonly $db $query|ConvertFrom-String -Delimiter '\u007C' -PropertyNames ETag, AppId, AppActivityId, ActivityType, ActivityStatus, IsInUploadQueue, LastModifiedTime, ExpirationTime, StartTime, EndTime, Payload, PlatformDeviceId)
$dbcount = $dbresults.count
$sw.stop()
$T0 = $sw1.Elapsed
write-progress -id 1 -activity "Running SQLite query" -status "Query Finished in $T0  -> $dbcount Entries found."
if($dbcount -eq 0){'Sorry - 0 entries found';exit}



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


$Registry = @(foreach ($entry in $DeviceID){$ra++
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
            )

# Hash table with Known Folder GUIDs s 
# "https://docs.microsoft.com/en-us/dotnet/framework/winforms/controls/known-folder-guids-for-file-dialog-custom-places"
#
# HKLM: \SOFTWARE\Mozilla\Firefox\TaskBarIDs :
# 308046B0AF4A39CB is Mozilla Firefox 64bit
# E7CF176E110C211B is Mozilla Firefox 32bit

$known = @{
            "308046B0AF4A39CB" = "Mozilla Firefox 64bit";
            "E7CF176E110C211B" = "Mozilla Firefox 32bit";
            "DE61D971-5EBC-4F02-A3A9-6C82895E5C04" = "AddNewPrograms";
            "724EF170-A42D-4FEF-9F26-B60E846FBA4F" = "AdminTools";
            "A520A1A4-1780-4FF6-BD18-167343C5AF16" = "AppDataLow";
            "A305CE99-F527-492B-8B1A-7E76FA98D6E4" = "AppUpdates";
            "9E52AB10-F80D-49DF-ACB8-4330F5687855" = "CDBurning";
            "DF7266AC-9274-4867-8D55-3BD661DE872D" = "ChangeRemovePrograms";
            "D0384E7D-BAC3-4797-8F14-CBA229B392B5" = "CommonAdminTools";
            "C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D" = "CommonOEMLinks";
            "0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8" = "CommonPrograms";
            "A4115719-D62E-491D-AA7C-E74B8BE3B067" = "CommonStartMenu";
            "82A5EA35-D9CD-47C5-9629-E15D2F714E6E" = "CommonStartup";
            "B94237E7-57AC-4347-9151-B08C6C32D1F7" = "CommonTemplates";
            "0AC0837C-BBF8-452A-850D-79D08E667CA7" = "Computer";
            "4BFEFB45-347D-4006-A5BE-AC0CB0567192" = "Conflict";
            "6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD" = "Connections";
            "56784854-C6CB-462B-8169-88E350ACB882" = "Contacts";
            "82A74AEB-AEB4-465C-A014-D097EE346D63" = "ControlPanel";
            "2B0F765D-C0E9-4171-908E-08A611B84FF6" = "Cookies";
            "B4BFCC3A-DB2C-424C-B029-7FE99A87C641" = "Desktop";
            "FDD39AD0-238F-46AF-ADB4-6C85480369C7" = "Documents";
            "374DE290-123F-4565-9164-39C4925E467B" = "Downloads";
            "1777F761-68AD-4D8A-87BD-30B759FA33DD" = "Favorites";
            "FD228CB7-AE11-4AE3-864C-16F3910AB8FE" = "Fonts";
            "CAC52C1A-B53D-4EDC-92D7-6B2E8AC19434" = "Games";
            "054FAE61-4DD8-4787-80B6-090220C4B700" = "GameTasks";
            "D9DC8A3B-B784-432E-A781-5A1130A75963" = "History";
            "4D9F7874-4E0C-4904-967B-40B0D20C3E4B" = "Internet";
            "352481E8-33BE-4251-BA85-6007CAEDCF9D" = "InternetCache";
            "BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968" = "Links";
            "F1B32785-6FBA-4FCF-9D55-7B8E7F157091" = "LocalAppData";
            "2A00375E-224C-49DE-B8D1-440DF7EF3DDC" = "LocalizedResourcesDir";
            "4BD8D571-6D19-48D3-BE97-422220080E43" = "Music";
            "C5ABBF53-E17F-4121-8900-86626FC2C973" = "NetHood";
            "D20BEEC4-5CA8-4905-AE3B-BF251EA09B53" = "Network";
            "2C36C0AA-5812-4B87-BFD0-4CD0DFB19B39" = "OriginalImages";
            "69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C" = "PhotoAlbums";
            "33E28130-4E1E-4676-835A-98395C3BC3BB" = "Pictures";
            "DE92C1C7-837F-4F69-A3BB-86E631204A23" = "Playlists";
            "76FC4E2D-D6AD-4519-A663-37BD56068185" = "Printers";
            "9274BD8D-CFD1-41C3-B35E-B13F55A758F4" = "PrintHood";
            "5E6C858F-0E22-4760-9AFE-EA3317B67173" = "Profile";
            "62AB5D82-FDC1-4DC3-A9DD-070D1D495D97" = "ProgramData";
            "905E63B6-C1BF-494E-B29C-65B732D3D21A" = "ProgramFiles";
            "F7F1ED05-9F6D-47A2-AAAE-29D317C6F066" = "ProgramFilesCommon";
            "6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D" = "ProgramFilesCommonX64";
            "DE974D24-D9C6-4D3E-BF91-F4455120B917" = "ProgramFilesCommonX86";
            "6D809377-6AF0-444B-8957-A3773F02200E" = "ProgramFilesX64";
            "7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E" = "ProgramFilesX86";
            "A77F5D77-2E2B-44C3-A6A2-ABA601054A51" = "Programs";
            "DFDF76A2-C82A-4D63-906A-5644AC457385" = "Public";
            "C4AA340D-F20F-4863-AFEF-F87EF2E6BA25" = "PublicDesktop";
            "ED4824AF-DCE4-45A8-81E2-FC7965083634" = "PublicDocuments";
            "3D644C9B-1FB8-4F30-9B45-F670235F79C0" = "PublicDownloads";
            "DEBF2536-E1A8-4C59-B6A2-414586476AEA" = "PublicGameTasks";
            "3214FAB5-9757-4298-BB61-92A9DEAA44FF" = "PublicMusic";
            "B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5" = "PublicPictures";
            "2400183A-6185-49FB-A2D8-4A392A602BA3" = "PublicVideos";
            "52A4F021-7B75-48A9-9F6B-4B87A210BC8F" = "QuickLaunch";
            "AE50C081-EBD2-438A-8655-8A092E34987A" = "Recent";
            "BD85E001-112E-431E-983B-7B15AC09FFF1" = "RecordedTV";
            "B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC" = "RecycleBin";
            "8AD10C31-2ADB-4296-A8F7-E4701232C972" = "ResourceDir";
            "3EB685DB-65F9-4CF6-A03A-E3EF65729F3D" = "RoamingAppData";
            "B250C668-F57D-4EE1-A63C-290EE7D1AA1F" = "SampleMusic";
            "C4900540-2379-4C75-844B-64E6FAF8716B" = "SamplePictures";
            "15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5" = "SamplePlaylists";
            "859EAD94-2E85-48AD-A71A-0969CB56A6CD" = "SampleVideos";
            "4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4" = "SavedGames";
            "7D1D3A04-DEBB-4115-95CF-2F29DA2920DA" = "SavedSearches";
            "EE32E446-31CA-4ABA-814F-A5EBD2FD6D5E" = "SEARCH_CSC";
            "98EC0E18-2098-4D44-8644-66979315A281" = "SEARCH_MAPI";
            "190337D1-B8CA-4121-A639-6D472D16972A" = "SearchHome";
            "8983036C-27C0-404B-8F08-102D10DCFD74" = "SendTo";
            "7B396E54-9EC5-4300-BE0A-2482EBAE1A26" = "SidebarDefaultParts";
            "A75D362E-50FC-4FB7-AC2C-A8BEAA314493" = "SidebarParts";
            "625B53C3-AB48-4EC1-BA1F-A1EF4146FC19" = "StartMenu";
            "B97D20BB-F46A-4C97-BA10-5E3608430854" = "Startup";
            "43668BF8-C14E-49B2-97C9-747784D784B7" = "SyncManager";
            "289A9A43-BE44-4057-A41B-587A76D7E7F9" = "SyncResults";
            "0F214138-B1D3-4A90-BBA9-27CBC0C5389A" = "SyncSetup";
            "1AC14E77-02E7-4E5D-B744-2EB1AE5198B7" = "System";
            "D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27" = "SystemX86";
            "A63293E8-664E-48DB-A079-DF759E0509F7" = "Templates";
            "5B3749AD-B49F-49C1-83EB-15370FBD4882" = "TreeProperties";
            "0762D272-C50A-4BB0-A382-697DCD729B80" = "UserProfiles";
            "F3CE0F7C-4901-4ACC-8648-D5D44B04EF8F" = "UsersFiles";
            "18989B1D-99B5-455B-841C-AB7C74E4DDFC" = "Videos";
            "F38BF404-1D43-42F2-9305-67DE0B28FC23" = "Windows"
            }          
   
$Output = foreach ($item in $dbresults ){$rb++
                    Write-Progress -id 3 -Activity "Creating Output" -Status "Combining Database - $rb of $($dbcount))" -PercentComplete (([double]$rb / $dbcount)*100) -ParentID 1
                    $rc=0
                    foreach ($rin in $Registry){$rc++
                    
                    Write-Progress -id 4 -Activity "Creating Output" -Status "with matching Registry entries - $rc of $($Registry.count))" -PercentComplete (([double]$rc / $Registry.count)*100) -ParentID 1
                    if($item.PlatformDeviceId -eq $rin.ID){
                    
                    $platform = ($item.Appid|convertfrom-json).platform
                    $type = ($item.Payload |ConvertFrom-Json).Type
                    $Duration = ($item.Payload |ConvertFrom-Json).activeDurationSeconds
                    $displayText = ($item.Payload |ConvertFrom-Json).displayText
                    $description = if ((($item.Payload |ConvertFrom-Json).description) -eq $item.AppActivityId)
                            {($item.Payload |ConvertFrom-Json).description} 
                            elseif(($item.Payload |ConvertFrom-Json).description -ne $null){($item.Payload |ConvertFrom-Json).description}
                            else {$item.AppActivityId}
                    
                    $displayname = ($item.Payload |ConvertFrom-Json).appDisplayName
                    $content = ($item.Payload |ConvertFrom-Json).contentUri
                    #Select the application name for x_exe, windows_win32 and Windows_universal entries
                    $AppName = $(if (($item.Appid|convertfrom-json).platform[0] -eq "x_exe_path"){($item.Appid|convertfrom-json).application[0]}
		                        elseif (($item.Appid|convertfrom-json).platform[0] -eq "windows_win32"){($item.Appid|convertfrom-json).application[0]}
		                        elseif (($item.Appid|convertfrom-json).platform[0] -eq "windows_universal"){($item.Appid|convertfrom-json).application[0]}
                                elseif (($item.Appid|convertfrom-json).platform[1] -eq "x_exe_path"){($item.Appid|convertfrom-json).application[1]}
		                        elseif (($item.Appid|convertfrom-json).platform[1] -eq "windows_win32"){($item.Appid|convertfrom-json).application[1]}
		                        elseif (($item.Appid|convertfrom-json).platform[1] -eq "windows_universal"){($item.Appid|convertfrom-json).application[1]}
                                elseif (($item.Appid|convertfrom-json).platform[2] -eq "x_exe_path"){($item.Appid|convertfrom-json).application[2]}
		                        elseif (($item.Appid|convertfrom-json).platform[2] -eq "windows_win32"){($item.Appid|convertfrom-json).application[2]}
		                        elseif (($item.Appid|convertfrom-json).platform[2] -eq "windows_universal"){($item.Appid|convertfrom-json).application[2]})                               
                     
                    # Replace known folder GUID with it's Name
                    foreach ($i in $known.Keys) {$AppName = $AppName -replace $i, $known[$i]}
                    # Fix endtime displaying 1970 date for File/App Open entries (entry is $null)
                    $endtime = if ($item.EndTime -eq 'Thursday, January 1, 1970 2:00:00 am' -or $item.EndTime -eq '01 Jan 70 2:00:00 am'){}else{Get-Date($item.EndTime) -f s}
                    
                    [PSCustomObject]@{
                                ETag = $item.ETag 
                                App_name = $AppName
                                DisplayText = $displayText
                                'Description/Hash' = $description
                                DisplayName = $displayname
                                Content = $content
                                Type = $type
                                ActivityType = $item.ActivityType 
                                ActivityStatus = $item.ActivityStatus
                                IsInUploadQueue = $item.IsInUploadQueue
                                Duration = $Duration
                                LastModifiedTime = Get-Date($item.LastModifiedTime) -f s
                                ExpirationTime = Get-Date($item.ExpirationTime) -f s
                                StartTime = Get-Date($item.StartTime) -f s
                                EndTime = $endtime
                                PlatformDeviceId = $item.PlatformDeviceId 
                                DeviceType = if($rin.Type -eq 15){"Laptop"}elseif($rin.Type -eq 9){"Desktop PC"}elseif($rin.Type -eq 8){"SmartPhone"}else{$rin.Type}
                                Name = $rin.Name
                                Make = $rin.Make
                                Model = $rin.Model
                                }
                        }                             
              }
}

$sw1.stop()           
$T = $sw1.Elapsed

#Create output - user can copy paste selected items to text file, MS Excel spreadsheet etc.
$Output|Out-GridView -PassThru -Title "Windows Timeline - ActiveBias= $Biasd - $dbcount entries found in $T"           
