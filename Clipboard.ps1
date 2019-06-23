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
Catch{Write-warning "(Clipboard.ps1):" -f Yellow -nonewline; Write-Host " User Cancelled" -f White; exit}

$db = $File
$sw = [Diagnostics.Stopwatch]::StartNew()
$sw1 = [Diagnostics.Stopwatch]::StartNew()
$dbresults=@()
$Query = @"
Select
    etag,
    datetime(Activity.StartTime, 'unixepoch') as 'StartTime',
	case 
		when json_extract(Activity.AppId, '$[0].application') = '308046B0AF4A39CB' 
			then 'Mozilla Firefox-64bit'
			when json_extract(Activity.AppId, '$[0].application') = 'E7CF176E110C211B'
			then 'Mozilla Firefox-32bit'
		when json_extract(Activity.AppId, '$[1].application') = '308046B0AF4A39CB'
			then 'Mozilla Firefox-64bit'
			when json_extract(Activity.AppId, '$[1].application') = 'E7CF176E110C211B'
			then 'Mozilla Firefox-32bit'
		when length (json_extract(Activity.AppId, '$[1].application')) between 17 and 22 
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
	case 
		when ClipboardPayload NOTNULL
		and Activity.ActivityType = 10
		and json_extract(Activity.ClipboardPayload, '$[0].formatName') = 'Text' 
		then json_extract(Activity.ClipboardPayload, '$[0].content') 
		end as 'ClipboardPayloadText',
	Activity.'Group' as 'AGroup',
    Activity.PackageIdHash as 'PackageIdHash', -- Unique hash of the application (different version of the same application has a different hash)
		 '{' || substr(hex(Activity.Id), 1, 8) || '-' ||
				substr(hex(Activity.Id), 9, 4) || '-' ||
				substr(hex(Activity.Id), 13, 4) || '-' ||
				substr(hex(Activity.Id), 17, 4) || '-' ||
				substr(hex(Activity.Id), 21, 12) || '}' as 'ID',
    case 
		when hex(Activity.ParentActivityId) = '00000000000000000000000000000000'
		then '' 
		else  
		 '{' || substr(hex(Activity.ParentActivityId), 1, 8) || '-' || 
				substr(hex(Activity.ParentActivityId), 9, 4) || '-' || 
				substr(hex(Activity.ParentActivityId), 13, 4) || '-' || 
				substr(hex(Activity.ParentActivityId), 17, 4) || '-' || 
				substr(hex(Activity.ParentActivityId), 21, 12) || '}' 
	end as 'ParentActivityId', --this ID  can be used to find the source/target of the copy/paste operation	
	Activity.PlatformDeviceId as 'DeviceID' --Can be used to identify the source device in NTUSER.dat
		
from Activity
where ClipboardPayloadText NOTNULL or AGroup in ('Copy','Paste') 
order by Etag desc
"@ 
write-progress -id 1 -activity "Running SQLite query (Might take a few minutes if dB is large)" 

$dbresults = @(sqlite3.exe -readonly $db $query -separator "||"|ConvertFrom-String -Delimiter '\u007C\u007C' -PropertyNames ETag, StartTime, Application, ClipboardPayloadText, AGroup, ID, ParentActivityId, DeviceID  )
$dbcount = $dbresults.count
$sw.stop()
$T0 = $sw1.Elapsed
write-progress -id 1 -activity "Running SQLite query" -status "Query Finished in $T0  -> $dbcount Entries found."
if($dbcount -eq 0){'Sorry - 0 entries found';exit}
$rb=0       
   
$Output = foreach ($item in $dbresults ){$rb++
                    
                                                          
                    [PSCustomObject]@{
                                'ETag'                =       $item.ETag
                                'Start Time (UTC)'    =       $item.StartTime
                                'Application'         =       $item.Application
                                'ClipboardPayload'    =       [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($item.ClipboardPayloadText))
                                'Group'               =       $item.AGroup
                                'ID'                  =       $item.ID
                                'ParentActivityId'    =       $item.ParentActivityId
                                'DeviceID'            =       $item.DeviceID
                                      }
                   }     

$sw1.stop()           
$T = $sw1.Elapsed

#Create output - user can copy paste selected items to text file, MS Excel spreadsheet etc.
$Output|Out-GridView -PassThru -Title  "Windows Timeline - $dbcount entries found in $T"           
