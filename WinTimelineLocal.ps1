##Requires -RunAsAdministrator
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
clear-host
# Check Validity of script
if((Get-AuthenticodeSignature $MyInvocation.MyCommand.Path).Status -ne "Valid"){

$check = [System.Windows.Forms.MessageBox]::Show($this,"WARNING:`n$(Split-path $MyInvocation.MyCommand.Path -Leaf) has been modified since it was signed.`nPress 'YES' to Continue or 'No' to Exit", "Warning",'YESNO',48)
switch ($check) {
"YES"{Continue}
"NO"{Exit}
    }
}
#Check if SQLite exists
try{write-host "sqlite3.exe version => "-f Yellow -nonewline; sqlite3.exe -version }
catch {
    write-host "It seems that you do not have sqlite3.exe in the system path"
    write-host "Please read below`n" -f Yellow
    write-host "Install SQLite On Windows:`n
        Go to SQLite download page, and download precompiled binaries from the Windows section.
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
Catch{Write-warning " User Cancelled"; exit}

#Check if DEviceCache has entries
try{    $reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey("CurrentUser", "default")
		$keys = $reg.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\")
        $RegCount = $keys.SubKeyCount
        $DeviceID = $keys.GetSubKeyNames()

}
catch{Write-warning " No DeviceCache entries exist in HKCU"; exit} 
if($RegCount -eq 0){write-host "Sorry, No devices found in HKCU";exit}

$db = $File
$sw = [Diagnostics.Stopwatch]::StartNew()
$sw1 = [Diagnostics.Stopwatch]::StartNew()
$dbresults=@{}
$Query = @"
select 
       ETag,
       AppId, 
	   case when AppActivityId not like '%-%-%-%-%' then AppActivityId
		else trim(AppActivityId,'ECB32AF3-1440-4086-94E3-5311F97F89C4\') end as 'AppActivityId',
       ActivityType as 'Activity_type', 
       case ActivityStatus 
		when 1 then 'Active' when 2 then 'Updated' when 3 then 'Deleted' when 4 then 'Ignored' 
		end as 'ActivityStatus',
	   Smartlookup.'group' as 'Group', 
       MatchID,
       'No' AS 'IsInUploadQueue', 
	   Priority as 'Priority',	
	   ClipboardPayload,
       datetime(LastModifiedTime, 'unixepoch', 'localtime')as 'LastModifiedTime',
       datetime(ExpirationTime, 'unixepoch', 'localtime') as 'ExpirationTime',
       datetime(StartTime, 'unixepoch', 'localtime') as 'StartTime',
       datetime(EndTime, 'unixepoch', 'localtime') as 'EndTime',
	   case 
		when CreatedInCloud > 0 
		then datetime(CreatedInCloud, 'unixepoch', 'localtime') 
		else '' 
	   end as 'CreatedInCloud',
	   case 
		when OriginalLastModifiedOnClient > 0 
		then datetime(OriginalLastModifiedOnClient, 'unixepoch', 'localtime') 
		else '' 
	   end as 'OriginalLastModifiedOnClient',
       Tag,
       PlatformDeviceId,
       Payload  
       
from   Smartlookup
order by Etag desc
"@ 
write-progress -id 1 -activity "Running SQLite query" 


$dbresults = @(sqlite3.exe -readonly $db $query -separator "||"|ConvertFrom-String -Delimiter '\u007C\u007C' -PropertyNames ETag, AppId, AppActivityId, ActivityType, ActivityStatus, Group, MatchID, IsInUploadQueue, Priority, ClipboardPayload, LastModifiedTime, ExpirationTime, StartTime, EndTime, CreatedInCloud, OriginalLastModifiedOnClient, Tag, PlatformDeviceId, Payload)


$dbcount = $dbresults.count
$sw.stop()
$T0 = $sw1.Elapsed
write-progress -id 1 -activity "Running SQLite query" -status "Query Finished in $T0  -> $dbcount Entries found."
if($dbcount -eq 0){write-warning 'Sorry - 0 entries found';exit}

#Query HKCU, check results against the Database 

$Registry = @{}

$Registry = @(foreach ($entry in $DeviceID){
            

            $dpath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\"
            
            Write-Progress -id 2 -Activity "Getting Entries" -Status "HKCU Entries: $($RegCount)" -ParentID 1
            
            $ID = $entry
            $key = $reg.OpenSubKey("Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\$($entry)")

                $Type = $key.getvalue("DeviceType") 
                $Name = $key.getvalue("DeviceName")
                $Make = $key.getvalue("DeviceMake") 
                $Model= $key.getvalue("DeviceModel") 
                
                [PSCustomObject]@{
                                ID =    $ID
                                Type =  $Type
                                Name =  $Name
                                Make =  $Make
                                Model = $Model
                     }
                $key.Close()
                $key.Dispose()
                 }
            )

$reg.close()         
$reg.Dispose() 
          
write-host "`nRegistry Devices: " -f White
$registry|sort -Property Type|Format-Table

# HKLM: \SOFTWARE\Mozilla\Firefox\TaskBarIDs :
# 308046B0AF4A39CB is Mozilla Firefox 64bit
# E7CF176E110C211B is Mozilla Firefox 32bit

# Hash table with Known Folder GUIDs  
# Reference: "https://docs.microsoft.com/en-us/dotnet/framework/winforms/controls/known-folder-guids-for-file-dialog-custom-places"

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
            "F3CE0F7C-4901-4ACC-8648-D5D44B04EF8F" = "UserFiles";
            "18989B1D-99B5-455B-841C-AB7C74E4DDFC" = "Videos";
            "F38BF404-1D43-42F2-9305-67DE0B28FC23" = "Windows"
            }          

# Get all "Microsoft.AutoGenerated" apps
# https://docs.microsoft.com/en-us/powershell/module/startlayout/get-startapps?view=win10-ps
try{$apps = get-startapps |where -Property AppId -match "Microsoft.AutoGenerated"}
catch{$apps = $null}
   
$Output = foreach ($item in $dbresults ){
                    Write-Progress -id 3 -Activity "Creating Output" -Status "Combining Database entries with NTUser.dat info" -ParentID 1
                    $content = $KnownFolderId=$Objectid=$volumeid= $contentdata=$contenturl = $null
                    
                    # Get Payload information
                    if(![string]::IsNullOrEmpty($item.Payload)){
                    $type =        if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).Type}else{$null}
                    $Duration =    if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).activeDurationSeconds}else{$null}
                    $timezone =    if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).userTimezone}else{$null}
                    $devPlatform = if($item.ActivityType -eq 6){($item.Payload |ConvertFrom-Json).devicePlatform}else{$null}
                    $displayText = if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).displayText}else{$null}
                    $description = if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).description} else{$null}
                    $displayname = if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).appDisplayName}else{$null}
                    $content =     if($item.ActivityType -eq 5){($item.Payload |ConvertFrom-Json).contentUri}
                               elseif($item.ActivityType -eq 10){[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String(($item.Payload|ConvertFrom-Json)."1".content))}
                               else{$null}
                    $Notification = if($item.ActivityType -eq 2){$item.Payload}else{$null}
                    }
                    
                    # Select the platform & application name for x_exe, windows_win32 and Windows_universal entries
                    $platform = if    (($item.Appid | convertfrom-json).platform[0] -match "afs_crossplatform")
							  {($item.Appid | convertfrom-json).platform[1] }
						else { ($item.Appid | convertfrom-json).platform[0] }
			
			        $Synched = if (![string]::IsNullOrEmpty($item.Appid))
						{
						   if (($item.Appid | convertfrom-json).platform -contains "afs_crossplatform") { "Yes" }
						   else { }
						}
                    
                    $AppName  = if($item.ActivityType -in (2,3,11,12,15)){($item.Appid|convertfrom-json).application[0]}
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
                    
                    if($AppName -match "Microsoft.AutoGenerated"){if (!!($apps | where -Property AppId -match "$AppName").Name) { $AppName = ($apps | where -Property AppId -match "$AppName").Name }}
                    elseif($AppName -match "PID00"){$AppName  =  "$($AppName) ($([Convert]::TouInt64($AppName.TrimStart("*PID"),16)))"}

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
                    
                    if (($item.ActivityType -eq 3) -and (![string]::IsNullOrEmpty($item.Payload)))
                    {
                    $backupType =         ($item.Payload | ConvertFrom-Json).backupType 
				    $devmodel =           ($item.Payload | ConvertFrom-Json).deviceName
				    $deviceIdentifier =   ($item.Payload | ConvertFrom-Json).deviceIdentifier
				    $backupcreationDate = ($item.Payload | ConvertFrom-Json).creationDate
				    $backupupdatedDate =  ($item.Payload | ConvertFrom-Json).updatedDate
                    }
                    else{$backupType=$devmodel=$deviceIdentifier=$backupcreationDate=$backupupdatedDate=$null}

                    # The ActivityType "3"'s Payload json field :"encryptedBackup" 
                    # is encoded using RSA v1.5 and AES-HMAC-SHA2 Encryption
                    # thus ignored. 
                    #
                    # "encryptedBackup" -> Base64 decoded -> {"alg":"A128KW","enc":"A128CBC-HS256"}
                    #
                    # Ref: https://tools.ietf.org/html/draft-ietf-jose-json-web-encryption-14#section-4.2 
                    # Ref: https://tools.ietf.org/id/draft-ietf-jose-cookbook-02.html#jwe-rsa15-key

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
                                MatchID      =     $item.MatchID
                                Tag =              $item.Tag
                                Type =             $type
                                ActivityType =          if ($item.ActivityType -eq 5){"Open App/File/Page (5)"}
                                                    elseif ($item.ActivityType -eq 6){"App In Use/Focus (6)"}
                                                    elseif ($item.ActivityType -eq 2){"Notification (2)"}
                                                    elseif ($item.ActivityType -eq 3){"Mobile Device Backup (3)"}
                                                    elseif ($item.ActivityType -eq 10){"Clipboard Text (10)"}
                                                    elseif ($item.ActivityType -in (11,12,15)){"System ($($item.ActivityType))"}
                                                    elseif ($item.ActivityType -eq 16){"Copy/Paste (16)"}
                                                    else{$item.ActivityType}
                                ActivityStatus =   $item.ActivityStatus
                                DevicePlatform  =  $devPlatform
                                Platform        =  $platform
                                IsInUploadQueue =  $item.IsInUploadQueue
                                Synched         = $Synched
                                Priority        = $item.Priority
                                CopiedText       = $clipboard
                                Notification     = $Notification
                                Duration =         if ($item.ActivityType -eq 6){[timespan]::fromseconds($Duration)}else{$null}
                                CalculatedDuration = if (($item.ActivityType) -eq 6 -and ($item.endtime -ge $item.StartTime )){([datetime] $item.endtime - [datetime] $item.StartTime)}else{$null}
                                LastModifiedTime = Get-Date($item.LastModifiedTime) -f s
                                ExpirationTime =   Get-Date($item.ExpirationTime) -f s
                                StartTime =        if(![string]::IsNullOrEmpty($item.StartTime)){Get-Date($item.StartTime) -f s}else{}
                                EndTime =          $endtime
                                CreatedInCloud   = if(![string]::IsNullOrEmpty($item.CreatedInCloud)){Get-Date($item.CreatedInCloud) -f s}else{}
                                OriginalLastModifiedOnClient = if(![string]::IsNullOrEmpty($item.OriginalLastModifiedOnClient)){Get-Date($item.OriginalLastModifiedOnClient) -f s}else{}
                                TimeZone =         $timezone
                                PlatformDeviceId = $item.PlatformDeviceId 
                                DeviceType =       if (!!$rid){
                                                       if($rid.Type -eq 15){"Windows 10 Laptop"}
                                                   elseif($rid.Type -eq 1) {"Xbox One"}
                                                   elseif($rid.Type -eq 0) {"Windows 10X device"}
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
                                DeviceModel   = $devmodel
				                DeviceID      = $deviceIdentifier
				                BackupType    = $backupType
				                BackupCreated = $backupcreationDate
				                BackupUpdated = $backupupdatedDate
                                }
                        }                             


$sw1.stop()           
$T = $sw1.Elapsed

#Create output - user can copy paste selected items to text file, MS Excel spreadsheet etc.
$Output|Out-GridView -PassThru -Title "Windows Timeline - $dbcount entries found in $T"  
# SIG # Begin signature block
# MIIfcAYJKoZIhvcNAQcCoIIfYTCCH10CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCCaLfpfoH8UNvN
# Ct3xVMnEJsSy6i+0wc7AZDcEDeBs46CCGf4wggQVMIIC/aADAgECAgsEAAAAAAEx
# icZQBDANBgkqhkiG9w0BAQsFADBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3Qg
# Q0EgLSBSMzETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2ln
# bjAeFw0xMTA4MDIxMDAwMDBaFw0yOTAzMjkxMDAwMDBaMFsxCzAJBgNVBAYTAkJF
# MRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWdu
# IFRpbWVzdGFtcGluZyBDQSAtIFNIQTI1NiAtIEcyMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAqpuOw6sRUSUBtpaU4k/YwQj2RiPZRcWVl1urGr/SbFfJ
# MwYfoA/GPH5TSHq/nYeer+7DjEfhQuzj46FKbAwXxKbBuc1b8R5EiY7+C94hWBPu
# TcjFZwscsrPxNHaRossHbTfFoEcmAhWkkJGpeZ7X61edK3wi2BTX8QceeCI2a3d5
# r6/5f45O4bUIMf3q7UtxYowj8QM5j0R5tnYDV56tLwhG3NKMvPSOdM7IaGlRdhGL
# D10kWxlUPSbMQI2CJxtZIH1Z9pOAjvgqOP1roEBlH1d2zFuOBE8sqNuEUBNPxtyL
# ufjdaUyI65x7MCb8eli7WbwUcpKBV7d2ydiACoBuCQIDAQABo4HoMIHlMA4GA1Ud
# DwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBSSIadKlV1k
# sJu0HuYAN0fmnUErTDBHBgNVHSAEQDA+MDwGBFUdIAAwNDAyBggrBgEFBQcCARYm
# aHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVwb3NpdG9yeS8wNgYDVR0fBC8w
# LTAroCmgJ4YlaHR0cDovL2NybC5nbG9iYWxzaWduLm5ldC9yb290LXIzLmNybDAf
# BgNVHSMEGDAWgBSP8Et/qC5FJK5NUPpjmove4t0bvDANBgkqhkiG9w0BAQsFAAOC
# AQEABFaCSnzQzsm/NmbRvjWek2yX6AbOMRhZ+WxBX4AuwEIluBjH/NSxN8RooM8o
# agN0S2OXhXdhO9cv4/W9M6KSfREfnops7yyw9GKNNnPRFjbxvF7stICYePzSdnno
# 4SGU4B/EouGqZ9uznHPlQCLPOc7b5neVp7uyy/YZhp2fyNSYBbJxb051rvE9ZGo7
# Xk5GpipdCJLxo/MddL9iDSOMXCo4ldLA1c3PiNofKLW6gWlkKrWmotVzr9xG2wSu
# kdduxZi61EfEVnSAR3hYjL7vK/3sbL/RlPe/UOB74JD9IBh4GCJdCC6MHKCX8x2Z
# faOdkdMGRE4EbnocIOM28LZQuTCCBMYwggOuoAMCAQICDCRUuH8eFFOtN/qheDAN
# BgkqhkiG9w0BAQsFADBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2ln
# biBudi1zYTExMC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBT
# SEEyNTYgLSBHMjAeFw0xODAyMTkwMDAwMDBaFw0yOTAzMTgxMDAwMDBaMDsxOTA3
# BgNVBAMMMEdsb2JhbFNpZ24gVFNBIGZvciBNUyBBdXRoZW50aWNvZGUgYWR2YW5j
# ZWQgLSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANl4YaGWrhL/
# o/8n9kRge2pWLWfjX58xkipI7fkFhA5tTiJWytiZl45pyp97DwjIKito0ShhK5/k
# Ju66uPew7F5qG+JYtbS9HQntzeg91Gb/viIibTYmzxF4l+lVACjD6TdOvRnlF4RI
# shwhrexz0vOop+lf6DXOhROnIpusgun+8V/EElqx9wxA5tKg4E1o0O0MDBAdjwVf
# ZFX5uyhHBgzYBj83wyY2JYx7DyeIXDgxpQH2XmTeg8AUXODn0l7MjeojgBkqs2Iu
# YMeqZ9azQO5Sf1YM79kF15UgXYUVQM9ekZVRnkYaF5G+wcAHdbJL9za6xVRsX4ob
# +w0oYciJ8BUCAwEAAaOCAagwggGkMA4GA1UdDwEB/wQEAwIHgDBMBgNVHSAERTBD
# MEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxz
# aWduLmNvbS9yZXBvc2l0b3J5LzAJBgNVHRMEAjAAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMEYGA1UdHwQ/MD0wO6A5oDeGNWh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5j
# b20vZ3MvZ3N0aW1lc3RhbXBpbmdzaGEyZzIuY3JsMIGYBggrBgEFBQcBAQSBizCB
# iDBIBggrBgEFBQcwAoY8aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNvbS9jYWNl
# cnQvZ3N0aW1lc3RhbXBpbmdzaGEyZzIuY3J0MDwGCCsGAQUFBzABhjBodHRwOi8v
# b2NzcDIuZ2xvYmFsc2lnbi5jb20vZ3N0aW1lc3RhbXBpbmdzaGEyZzIwHQYDVR0O
# BBYEFNSHuI3m5UA8nVoGY8ZFhNnduxzDMB8GA1UdIwQYMBaAFJIhp0qVXWSwm7Qe
# 5gA3R+adQStMMA0GCSqGSIb3DQEBCwUAA4IBAQAkclClDLxACabB9NWCak5BX87H
# iDnT5Hz5Imw4eLj0uvdr4STrnXzNSKyL7LV2TI/cgmkIlue64We28Ka/GAhC4evN
# GVg5pRFhI9YZ1wDpu9L5X0H7BD7+iiBgDNFPI1oZGhjv2Mbe1l9UoXqT4bZ3hcD7
# sUbECa4vU/uVnI4m4krkxOY8Ne+6xtm5xc3NB5tjuz0PYbxVfCMQtYyKo9JoRbFA
# uqDdPBsVQLhJeG/llMBtVks89hIq1IXzSBMF4bswRQpBt3ySbr5OkmCCyltk5lXT
# 0gfenV+boQHtm/DDXbsZ8BgMmqAc6WoICz3pZpendR4PvyjXCSMN4hb6uvM0MIIF
# PDCCBCSgAwIBAgIRALjpohQ9sxfPAIfj9za0FgUwDQYJKoZIhvcNAQELBQAwfDEL
# MAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
# BxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSQwIgYDVQQDExtT
# ZWN0aWdvIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcNMjAwMjIwMDAwMDAwWhcNMjIw
# MjE5MjM1OTU5WjCBrDELMAkGA1UEBhMCR1IxDjAMBgNVBBEMBTU1NTM1MRUwEwYD
# VQQIDAxUaGVzc2Fsb25pa2kxDzANBgNVBAcMBlB5bGFpYTEbMBkGA1UECQwSMzIg
# Qml6YW5pb3UgU3RyZWV0MSMwIQYDVQQKDBpLYXRzYXZvdW5pZGlzIEtvbnN0YW50
# aW5vczEjMCEGA1UEAwwaS2F0c2F2b3VuaWRpcyBLb25zdGFudGlub3MwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDa2C7McRZbPAGLVPCcYCmhqbVRVGBV
# JXZhqJKFbJA95o2z4AiyB7C/cQGy1F3c3jW9Balp3uESAsy6JrJI+g62vxzk6chx
# tcre1PPnjqdcDQyetHRA7ZseDnFhk6DvxDR0emBHmdycAjWq3kACWwkKQADyuQ3D
# 6MxRhG3InKkv+e1OjVjW8zJobo8wxfVVrxDML8TIOu2QzgpCMf67gcFtzhtkNYKO
# 0ukSgVZ4YXrv8tenw5jLxR9Yv5RKGE1yXzafUy17RsxsEIEZx2IGBxmSF2HJCSbW
# vEXtcVslnzmttRS+tyNBxnXB/NK8Zf2h189414mjZy/pfUmTMQwcZOKdAgMBAAGj
# ggGGMIIBgjAfBgNVHSMEGDAWgBQO4TqoUzox1Yq+wbutZxoDha00DjAdBgNVHQ4E
# FgQUH9X2tKd+540Ixy1znv3RfwoyR9cwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB
# /wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMEAG
# A1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMCMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8v
# c2VjdGlnby5jb20vQ1BTMEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuc2Vj
# dGlnby5jb20vU2VjdGlnb1JTQUNvZGVTaWduaW5nQ0EuY3JsMHMGCCsGAQUFBwEB
# BGcwZTA+BggrBgEFBQcwAoYyaHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UlNBQ29kZVNpZ25pbmdDQS5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNl
# Y3RpZ28uY29tMA0GCSqGSIb3DQEBCwUAA4IBAQBbQmN6mJ6/Ff0c3bzLtKFKxbXP
# ZHjHTxB74mqp38MGdhMfPsQ52I5rH9+b/d/6g6BKJnTz293Oxcoa29+iRuwljGbv
# /kkjM80iALnorUQsk+RA+jCJ9XTqUbiWtb2Zx828GoCE8OJ1EyAozVVEA4bcu+nc
# cAFDd78YGyguDMHaYfnWjA2R2HkT4nYSu2u80+FeRuodmnB2dcM89k0a+XjuhDuG
# 8DJRcI2tjRZnR7geRHwVEFFPc/ZdAjRaFpAUgEArCWoIHAMtIf0W/fdtXrbdIeg9
# ibmcGiFH70Q/VvaXoDx+9qYLeYvEtAAEiHflfFElV2WIC+N47DLZxpkO7D68MIIF
# 3jCCA8agAwIBAgIQAf1tMPyjylGoG7xkDjUDLTANBgkqhkiG9w0BAQwFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
# eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT
# JVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAwMjAx
# MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Ck5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUg
# VVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQCAEmUXNg7D2wiz0KxXDXbtzSfTTK1Qg2HiqiBNCS1kCdzOiZ/MPans9s/B3PHT
# sdZ7NygRK0faOca8Ohm0X6a9fZ2jY0K2dvKpOyuR+OJv0OwWIJAJPuLodMkYtJHU
# YmTbf6MG8YgYapAiPLz+E/CHFHv25B+O1ORRxhFnRghRy4YUVD+8M/5+bJz/Fp0Y
# vVGONaanZshyZ9shZrHUm3gDwFA66Mzw3LyeTP6vBZY1H1dat//O+T23LLb2VN3I
# 5xI6Ta5MirdcmrS3ID3KfyI0rn47aGYBROcBTkZTmzNg95S+UzeQc0PzMsNT79uq
# /nROacdrjGCT3sTHDN/hMq7MkztReJVni+49Vv4M0GkPGw/zJSZrM233bkf6c0Pl
# fg6lZrEpfDKEY1WJxA3Bk1QwGROs0303p+tdOmw1XNtB1xLaqUkL39iAigmTYo61
# Zs8liM2EuLE/pDkP2QKe6xJMlXzzawWpXhaDzLhn4ugTncxbgtNMs+1b/97lc6wj
# Oy0AvzVVdAlJ2ElYGn+SNuZRkg7zJn0cTRe8yexDJtC/QV9AqURE9JnnV4eeUB9X
# VKg+/XRjL7FQZQnmWEIuQxpMtPAlR1n6BB6T1CZGSlCBst6+eLf8ZxXhyVeEHg9j
# 1uliutZfVS7qXMYoCAQlObgOK6nyTJccBz8NUvXt7y+CDwIDAQABo0IwQDAdBgNV
# HQ4EFgQUU3m/WqorSs9UgOHYm8Cd8rIDZsswDgYDVR0PAQH/BAQDAgEGMA8GA1Ud
# EwEB/wQFMAMBAf8wDQYJKoZIhvcNAQEMBQADggIBAFzUfA3P9wF9QZllDHPFUp/L
# +M+ZBn8b2kMVn54CVVeWFPFSPCeHlCjtHzoBN6J2/FNQwISbxmtOuowhT6KOVWKR
# 82kV2LyI48SqC/3vqOlLVSoGIG1VeCkZ7l8wXEskEVX/JJpuXior7gtNn3/3ATiU
# FJVDBwn7YKnuHKsSjKCaXqeYalltiz8I+8jRRa8YFWSQEg9zKC7F4iRO/Fjs8PRF
# /iKz6y+O0tlFYQXBl2+odnKPi4w2r78NBc5xjeambx9spnFixdjQg3IM8WcRiQyc
# E0xyNN+81XHfqnHd4blsjDwSXWXavVcStkNr/+XeTWYRUc+ZruwXtuhxkYzeSf7d
# NXGiFSeUHM9h4ya7b6NnJSFd5t0dCy5oGzuCr+yDZ4XUmFF0sbmZgIn/f3gZXHlK
# YC6SQK5MNyosycdiyA5d9zZbyuAlJQG03RoHnHcAP9Dc1ew91Pq7P8yF1m9/qS3f
# uQL39ZeatTXaw2ewh0qpKJ4jjv9cJ2vhsE/zB+4ALtRZh8tSQZXq9EfX7mRBVXyN
# WQKV3WKdwrnuWih0hKWbt5DHDAff9Yk2dDLWKMGwsAvgnEzDHNb842m1R0aBL6KC
# q9NjRHDEjf8tM7qtj3u1cIiuPhnPQCjY/MiQu12ZIvVS5ljFH4gxQ+6IHdfGjjxD
# ah2nGN59PRbxYvnKkKj9MIIF9TCCA92gAwIBAgIQHaJIMG+bJhjQguCWfTPTajAN
# BgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJz
# ZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNU
# IE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBB
# dXRob3JpdHkwHhcNMTgxMTAyMDAwMDAwWhcNMzAxMjMxMjM1OTU5WjB8MQswCQYD
# VQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdT
# YWxmb3JkMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3Rp
# Z28gUlNBIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAIYijTKFehifSfCWL2MIHi3cfJ8Uz+MmtiVmKUCGVEZ0MWLFEO2yhyem
# mcuVMMBW9aR1xqkOUGKlUZEQauBLYq798PgYrKf/7i4zIPoMGYmobHutAMNhodxp
# ZW0fbieW15dRhqb0J+V8aouVHltg1X7XFpKcAC9o95ftanK+ODtj3o+/bkxBXRIg
# CFnoOc2P0tbPBrRXBbZOoT5Xax+YvMRi1hsLjcdmG0qfnYHEckC14l/vC0X/o84X
# pi1VsLewvFRqnbyNVlPG8Lp5UEks9wO5/i9lNfIi6iwHr0bZ+UYc3Ix8cSjz/qfG
# FN1VkW6KEQ3fBiSVfQ+noXw62oY1YdMCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaA
# FFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBQO4TqoUzox1Yq+wbutZxoD
# ha00DjAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHSUE
# FjAUBggrBgEFBQcDAwYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMFAGA1Ud
# HwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RS
# U0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2BggrBgEFBQcBAQRqMGgwPwYI
# KwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FB
# ZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEATWNQ7Uc0SmGk295qKoyb8QAAHh1iezrX
# MsL2s+Bjs/thAIiaG20QBwRPvrjqiXgi6w9G7PNGXkBGiRL0C3danCpBOvzW9Ovn
# 9xWVM8Ohgyi33i/klPeFM4MtSkBIv5rCT0qxjyT0s4E307dksKYjalloUkJf/wTr
# 4XRleQj1qZPea3FAmZa6ePG5yOLDCBaxq2NayBWAbXReSnV+pbjDbLXP30p5h1zH
# QE1jNfYw08+1Cg4LBH+gS667o6XQhACTPlNdNKUANWlsvp8gJRANGftQkGG+OY96
# jk32nw4e/gdREmaDJhlIlc5KycF/8zoFm/lv34h/wCOe0h5DekUxwZxNqfBZslkZ
# 6GqNKQQCd3xLS81wvjqyVVp4Pry7bwMQJXcVNIr5NsxDkuS6T/FikyglVyn7URnH
# oSVAaoRXxrKdsbwcCtp8Z359LukoTBh+xHsxQXGaSynsCz1XUNLK3f2eBVHlRHjd
# Ad6xdZgNVCT98E7j4viDvXK6yz067vBeF5Jobchh+abxKgoLpbn0nu6YMgWFnuv5
# gynTxix9vTp3Los3QqBqgu07SqqUEKThDfgXxbZaeTMYkuO1dfih6Y4KJR7kHvGf
# Wocj/5+kUZ77OYARzdu1xKeogG/lU9Tg46LC0lsa+jImLWpXcBw8pFguo/NbSwfc
# Mlnzh6cabVgxggTIMIIExAIBATCBkTB8MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxJDAiBgNVBAMTG1NlY3RpZ28gUlNBIENvZGUgU2lnbmlu
# ZyBDQQIRALjpohQ9sxfPAIfj9za0FgUwDQYJYIZIAWUDBAIBBQCgTDAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAvBgkqhkiG9w0BCQQxIgQgRP+H3a0pRa15/QJz
# 2r/BNOX85zuQl3cEUjZwf1eJNLIwDQYJKoZIhvcNAQEBBQAEggEAvjXPc6zYaZI3
# tMkeD6jXq0GX37s1mMTodrTLYu3+GuGDm3gmkFlKz05Vo3ULy+jEcmuG9AfDkBrh
# tDO7lWO1SgDxLb3cecbnm/IT+a+QtePytTkeJTM1yWe4XqPbXrWxuyqqHv0lCj1L
# CBDii5vawcOL/I1ISh85NLbjUZtwAWGXKH/yTTASl8MNMV1hFbYFgCRJlEva/CSy
# Y7jBRXp5qUk+6n3a92G99e8u/m+U/FHN7n47caJHkRotKG2QohPXP1U08t5mTHy1
# MleEQVDoy5Ei8nuuKp063dweF/CYNtwuvTn3H8Sxc8oKR+m9MBlJ47ghC4pCfujV
# O6slHCKDy6GCArkwggK1BgkqhkiG9w0BCQYxggKmMIICogIBATBrMFsxCzAJBgNV
# BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9i
# YWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTI1NiAtIEcyAgwkVLh/HhRTrTf6
# oXgwDQYJYIZIAWUDBAIBBQCgggEMMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTIwMDMwMTEyMjAwNFowLwYJKoZIhvcNAQkEMSIEIMug
# ryKRxEzmWgzYSJS/gB6LNgAzPUXBW8x5odkv9zE8MIGgBgsqhkiG9w0BCRACDDGB
# kDCBjTCBijCBhwQUPsdm1dTUcuIbHyFDUhwxt5DZS2gwbzBfpF0wWzELMAkGA1UE
# BhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2Jh
# bFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMjU2IC0gRzICDCRUuH8eFFOtN/qh
# eDANBgkqhkiG9w0BAQEFAASCAQCwB+eZE4wez2LD7GO5nHMmUSgshrQzu0kZi3Z6
# nMYo4M0btO9BSm4/i3qgbk3H4lhADnq1GSHayXoSWy3lcb1In6UzMAMcdNFqgM6+
# SkTFrQUNnmjM1DPskj9KhJT87zpmEROEAGXq6MaZGIWQC1aG4XChFbUycOalBFLH
# Z8smGSjKvv4kpze3E2QUDRTwSLvPB+7paY6ozUDfVZMcBN5cKJTwvi97mM2MB7it
# X9qOujjEYMCKPbHmB3gZNdXbMh8hamh9j539wyoWBndZ/B/Qk3iFiQCs11XSesHC
# qu2DBgHZHBFYBanE4Z6NZuneUtLKdhgA00w7+rtYIys4BGwI
# SIG # End signature block
