#Requires -RunAsAdministrator
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
clear-host
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
# by running "SQLite3.exe -version" (you may have already an older version in your Path)

# Device Name and Model of the originating machine can be seen 
# in the HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\

# Show Open File Dialogs 
Function Get-FileName($initialDirectory, $Title ,$Filter)
{  
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
		try{reg unload HKEY_LOCAL_MACHINE\Temp }catch{}
		exit
} 
write-host "SHA256 Hash of ($File2) before access = " -f magenta -nonewline;write-host "($before)" -f Yellow

#End of File Selection

	
# Run SQLite query of the Selected dB
# The Query (between " " below)
# can also be copy/pasted and run on 'DB Browser for SQLite' 

Try{(Get-Item $File1).FullName|Out-Null}
Catch{Write-Host "(WinTimelineOffline.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White; 
		[gc]::Collect()		
		reg unload HKEY_LOCAL_MACHINE\Temp 
		exit
		}

#Timers 
$sw = [Diagnostics.Stopwatch]::StartNew()
$sw1 = [Diagnostics.Stopwatch]::StartNew()

#Database Query
$db = $File1
$dbresults=@{}
$Query = @"
select 
       ActivityOperation.ETag,
       ActivityOperation.AppId, 
	   case when ActivityOperation.AppActivityId not like '%-%-%-%-%' then ActivityOperation.AppActivityId
		else trim(ActivityOperation.AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\') end as 'AppActivityId',
       	ActivityOperation.ActivityType as 'Activity_type',
	    case ActivityOperation.OperationType 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus',
		ActivityOperation.'group' as 'Group',
        'Yes' AS 'IsInUploadQueue',
	   ActivityOperation.ClipboardPayload,	
       datetime(ActivityOperation.LastModifiedTime, 'unixepoch', 'localtime') as 'LastModifiedTime',
       datetime(ActivityOperation.ExpirationTime, 'unixepoch', 'localtime')as 'ExpirationTime',
       datetime(ActivityOperation.StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(ActivityOperation.EndTime, 'unixepoch', 'localtime') as 'EndTime',
       ActivityOperation.Tag, 
       ActivityOperation.PlatformDeviceId,
       ActivityOperation.Payload 
       
from   ActivityOperation 
       left outer join Activity on ActivityOperation.Id = Activity.Id
union
select 
       Activity.ETag,
       Activity.AppId, 
	   case when Activity.AppActivityId not like '%-%-%-%-%' then Activity.AppActivityId
		else trim(Activity.AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\') end as 'AppActivityId',
       	Activity.ActivityType as 'Activity_type', 
        case Activity.ActivityStatus 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus',
		Activity.'group' as 'Group',
       'No' AS 'IsInUploadQueue', 
	   Activity.ClipboardPayload,
       datetime(Activity.LastModifiedTime, 'unixepoch', 'localtime')as 'LastModifiedTime',
       datetime(Activity.ExpirationTime, 'unixepoch', 'localtime') as 'ExpirationTime',
       datetime(Activity.StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(Activity.EndTime, 'unixepoch', 'localtime') as 'EndTime',
       Activity.Tag,
       Activity.PlatformDeviceId,
       Activity.Payload  
       
from   Activity
where  Activity.Id not in (select ActivityOperation.Id from ActivityOperation)
order by Etag desc
"@ 
write-progress -id 1 -activity "Running SQLite query (Might take a few minutes if dB is large)" 

$dbresults = @(sqlite3.exe -readonly $db $query -separator "||"|ConvertFrom-String -Delimiter '\u007C\u007C' -PropertyNames ETag, AppId, AppActivityId, ActivityType, ActivityStatus, Group, IsInUploadQueue, ClipboardPayload, LastModifiedTime, ExpirationTime, StartTime, EndTime, Tag, PlatformDeviceId, Payload)
$dbcount = $dbresults.count

#Stop Timer 1
$sw.stop()
$T0 = $sw1.Elapsed
write-progress -id 1 -activity "Running SQLite query" -status "Query Finished in $T0 -> $dbcount Entries found." 
if($dbcount -eq 0){'Sorry - 0 entries found';exit}

#Load NTUSER.dat into a Temp subfolder in HKLM
reg load HKEY_LOCAL_MACHINE\Temp $File2
$ErrorActionPreference = "Stop"

try{
            
			$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey("LocalMachine", "default")
			$keys = $reg.OpenSubKey("Temp\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\")
            Write-Host -ForegroundColor Green "$File2 loaded OK"
			$RegCount = $keys.SubKeyCount
			if($RegCount -eq 0){write-host "No Devices found in selected NTUser.dat" -f Red;exit}
			$DeviceID = $keys.GetSubKeyNames()
            $keys.Close()
			$keys.Dispose()            

}
Catch{
	Write-Host -ForegroundColor Yellow "The selectd ($File2) does not have the" 
	Write-Host -ForegroundColor Yellow "'Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache' registry key." 
    if(!!$keys)
    {
    $keys.close()
    $keys.dispose()
    }	
    $reg.close()
    $reg.dispose()
    Remove-Variable -Name key,keys,reg,RegCount,DeviceID -ErrorAction SilentlyContinue
    [gc]::Collect()		
	reg unload HKEY_LOCAL_MACHINE\Temp 
    exit}
finally{
    }

#Query HKCU, check results against the Database 
$Registry = [pscustomobject]@{}

$ra=0
$rb=0

$Registry = @(foreach ($entry in $DeviceID){

                Write-Progress -id 2 -Activity "Getting Entries" -Status "HKCU Entries: $($RegCount)" -ParentID 1
            
                $key = $reg.OpenSubKey("Temp\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\$($entry)")
				
				$Type  = $key.getvalue("DeviceType")
				$Name  = $key.getvalue("DeviceName")
				$Make  = $key.getvalue("DeviceMake")
				$Model = $key.getvalue("DeviceModel")

                [PSCustomObject]@{
                                ID    = $entry
                                Type  = $Type
                                Name  = $Name
                                Make  = $Make
                                Model = $Model
                     }
                $key.Close()
                $key.dispose()
            }        
            )
            
            $reg.Close()
            $reg.Dispose()
            Remove-Variable -Name key,keys,reg,RegCount,DeviceID -ErrorAction SilentlyContinue
            [gc]::Collect()

write-host "`nRegistry Devices: " -f White
$registry|sort -Property Type|Format-Table          

# Hash table with Known Folder GUIDs s 
# "https://docs.microsoft.com/en-us/dotnet/framework/winforms/controls/known-folder-guids-for-file-dialog-custom-places"
#
# HKLM: \SOFTWARE\Mozilla\Firefox\TaskBarIDs :
# 308046B0AF4A39CB is Mozilla Firefox 64bit
# E7CF176E110C211B is Mozilla Firefox 32bit

$known =   @{
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

#Create output   
$Output = foreach ($item in $dbresults ){

                    Write-Progress -id 3 -Activity "Creating Output" -Status "Combining Database" -ParentID 1
                    $content = $KnownFolderId=$Objectid=$volumeid= $contentdata=$contenturl = $null
                    
                                       
                    $type =        if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).Type}else{""}
                    $Duration =    if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).activeDurationSeconds}else{""}
                    $devPlatform = if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).devicePlatform}else{""}
                    $timezone =    if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).userTimezone}else{""}
                    $displayText = if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).displayText}else{""}
                    $description = if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).description} else{""}
                    $displayname = if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).appDisplayName}else{""}
                    $content =     if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).contentUri}
                               elseif($item.ActivityType -eq 10){[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String(($item.Payload|ConvertFrom-Json)."1".content))}
                               else{""}
                    $Notification = if($item.ActivityType -eq 2){$item.Payload}else{}
                    # Select the platform & application name for x_exe, windows_win32 and Windows_universal entries
                    $platform = ($item.Appid|convertfrom-json).platform
                    $AppName  = if($item.ActivityType -in (11,12,15)){($item.Appid|convertfrom-json).application[0]}
                                else {
                                  $(if (($item.Appid|convertfrom-json).platform[0] -eq "x_exe_path"){($item.Appid|convertfrom-json).application[0]}
		                        elseif (($item.Appid|convertfrom-json).platform[0] -eq "windows_win32"){($item.Appid|convertfrom-json).application[0]}
		                        elseif (($item.Appid|convertfrom-json).platform[0] -eq "windows_universal"){($item.Appid|convertfrom-json).application[0]}
                                elseif (($item.Appid|convertfrom-json).platform[1] -eq "x_exe_path"){($item.Appid|convertfrom-json).application[1]}
		                        elseif (($item.Appid|convertfrom-json).platform[1] -eq "windows_win32"){($item.Appid|convertfrom-json).application[1]}
		                        elseif (($item.Appid|convertfrom-json).platform[1] -eq "windows_universal"){($item.Appid|convertfrom-json).application[1]}
                                elseif (($item.Appid|convertfrom-json).platform[2] -eq "x_exe_path"){($item.Appid|convertfrom-json).application[2]}
		                        elseif (($item.Appid|convertfrom-json).platform[2] -eq "windows_win32"){($item.Appid|convertfrom-json).application[2]}
		                        elseif (($item.Appid|convertfrom-json).platform[2] -eq "windows_universal"){($item.Appid|convertfrom-json).application[2]})
                                }                               
                    
                    # Get Clipboard copied text (Base 64 text decoded)
                    $clipboard = if($item.ActivityType -in (10)){[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String(($item.ClipboardPayload|ConvertFrom-Json).content))}
                     
                    # Replace known folder GUID with it's Name
                    foreach ($i in $known.Keys) {
                                        $AppName = $AppName -replace $i, $known[$i]
                                        }
                    
                    # Fix endtime displaying 1970 date for File/App Open entries (entry is $null)
                    $endtime = if ($item.EndTime -eq 'Thursday, January 1, 1970 2:00:00 am' -or $item.EndTime -eq '01 Jan 70 2:00:00 am'){}else{Get-Date($item.EndTime) -f s}
                    
                    # Check DeviceId against registry
                    $rid = $Registry | Where-Object { $_.id -eq $item.PlatformDeviceId }

                     # Get more info from ContentURI
                    if ($item.ActivityType -eq 5 -and !!$content) {
                    $contenturl    = if (($content.count -gt 0) -and ($content.split("?")[0] -match "file://")){$content.split("?")[0]}else{$content}
			        $contentdata   = if (($content.count -gt 0) -and (!!$content.split("?")[1])) { $content.split("?")[1].split("&") }else { $null }
			        $volumeid      = if (($contentdata.count -gt 0) -and ($contentdata[0] -match "VolumeID")) { $contentdata[0].trimstart("VolumeId={").trimend("}") }else { $null }
			        $Objectid      = if (($contentdata.count -gt 0) -and ($contentdata[1] -match "ObjectId")) { $contentdata[1].trimstart("ObjectId={").trimend("}") }else { $null }
			        $KnownFolderId = if (($contentdata.count -gt 0) -and ($contentdata[2] -match "KnownFolderId")) { $contentdata[2].trimstart("KnownFolderId=") }else { $null }
                    }

                    [PSCustomObject]@{
                                ETag =             $item.ETag 
                                App_name =         $AppName
                                DisplayName =      $displayname
                                DisplayText =      $displayText
                                Description =      $description
                                AppActivityId =    $item.AppActivityId
                                Content          = if(![string]::IsNullOrEmpty($contenturl)){[uri]::UnescapeDataString($contenturl)}else{$content}
				                VolumeID         = if (![string]::IsNullOrEmpty($volumeid)){$volumeid}else{$null}
				                Objectid         = if (![string]::IsNullOrEmpty($Objectid)) { $Objectid }else{ $null }
				                KnownFolder      = if (![string]::IsNullOrEmpty($KnownFolderId)) { $KnownFolderId }else{ $null }
                                Group         =    $item.Group
                                Tag =              $item.Tag
                                Type =             $type
                                ActivityType =          if ($item.ActivityType -eq 5){"Open App/File/Page (5)"}
                                                    elseif ($item.ActivityType -eq 6){"App In Use/Focus (6)"}
                                                    elseif ($item.ActivityType -eq 2){"Notification (2)"}
                                                    elseif ($item.ActivityType -eq 10){"Clipboard Text (10)"}
                                                    elseif ($item.ActivityType -in (11,12,15)){"System ($($item.ActivityType))"}
                                                    elseif ($item.ActivityType -eq 16){"Copy/Paste (16)"}
                                                    else{$item.ActivityType}
                                ActivityStatus =   $item.ActivityStatus
                                DevicePlatform  =  $devPlatform
                                IsInUploadQueue =  $item.IsInUploadQueue
                                CopiedText       = $clipboard
                                Notification     = $Notification
                                Duration =         if($Duration -ne ""){[timespan]::fromseconds($Duration)}else{""}
                                CalculatedDuration = if ($item.ActivityType -eq 6){([datetime] $item.endtime - [datetime] $item.StartTime)}else{""}
                                LastModifiedTime = Get-Date($item.LastModifiedTime) -f s
                                ExpirationTime =   Get-Date($item.ExpirationTime) -f s
                                StartTime =        Get-Date($item.StartTime) -f s
                                EndTime =          $endtime
                                TimeZone =         $timezone
                                PlatformDeviceId = $item.PlatformDeviceId 
                                DeviceType =       if (!!$rid){
                                                       if($rid.Type -eq 15){"Windows 10 Laptop"}
                                                   elseif($rid.Type -eq 1) {"Xbox One"}
                                                   elseif($rid.Type -eq 6) {"Apple iPhone"}
                                                   elseif($rid.Type -eq 7) {"Apple iPad"}
                                                   elseif($rid.Type -eq 8) {"Android device"}
                                                   elseif($rid.Type -eq 9) {"Windows 10 Desktop"}
                                                   elseif($rid.Type -eq 9) {"Desktop PC"}
                                                   elseif($rid.Type -eq 11){"Windows 10 Phone"}
                                                   elseif($rid.Type -eq 12){"Linux device"}
                                                   elseif($rid.Type -eq 13){"Windows IoT"}
                                                   elseif($rid.Type -eq 14){"Surface Hub"}
                                                     else{$rid.Type}
                                                  }else{ $null }    
                                                   # Reference: https://winprotocoldoc.blob.core.windows.net/productionwindowsarchives/MS-CDP/[MS-CDP].pdf
                                Name          = if (!!$rid) { $rid.name } else{ $null }
				                Make          = if (!!$rid) { $rid.make } else{ $null }
				                Model         = if (!!$rid) { $rid.model }else{ $null }
                                }

}

#Stop Timer2
$sw1.stop()           
$T = $sw1.Elapsed           
     
# Display results - user can copy paste selected items to text file, MS Excel spreadsheet etc.
$Output|Out-GridView -PassThru -Title "Windows Timeline $File1 with Device Information from $File2 - $dbcount entries found in $T "


[gc]::Collect()
try{reg unload HKEY_LOCAL_MACHINE\Temp} 
catch{
Write-Warning "There seems to be an issue unloading $($File2)."
Write-Host "Please open a new Powershell terminal Window, copy/paste" -NoNewline;write-host "reg unload HKEY_LOCAL_MACHINE\Temp" -ForegroundColor Magenta
Write-Host "close this Powershell terminal and run the above command in the other terminal Window"
exit}
 
$after = (Get-FileHash $File2 -Algorithm SHA256).Hash 
write-host "SHA256 Hash of ($File2) after access = " -f magenta -nonewline;write-host "($after)" -f Yellow
$result = (compare-object -ReferenceObject $before -DifferenceObject $after -IncludeEqual).SideIndicator 
write-host "The before and after Hashes of ($File2) are ($result) `n `n " -ForegroundColor White