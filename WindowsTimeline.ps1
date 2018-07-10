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
    
$db = $File
$sql = 
"
		select
		ActivityOperation.PlatformDeviceId as 'ID'
		from Activity_PackageId
		join ActivityOperation on Activity_PackageId.ActivityId = ActivityOperation.Id 
		where Activity_PackageId.ActivityId = ActivityOperation.Id
		union
		select
		Activity.platformdeviceid as 'ID'
		from Activity_PackageId
		join Activity on Activity_PackageId.ActivityId = Activity.Id 
		where Activity_PackageId.ActivityId = Activity.Id
		group by platformdeviceid
"

$dbresult = (sqlite3.exe $db $sql) 
$dbcount=$dbresult.count

#Query HKCU, check results against the Database 
	$DeviceID =  (Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\" -name)|Select-Object 
	$RegCount =$DeviceID.count
	$Output = foreach ($entry in $DeviceID){
	$dpath = join-path -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\TaskFlow\DeviceCache\" -childpath $entry

                                    $Type = (get-itemproperty -path $dpath).DeviceType
                                    $Name = (get-itemproperty -path $dpath).DeviceName
                                    $Make = (get-itemproperty -path $dpath).DeviceMake
                                    $Model = (get-itemproperty -path $dpath).DeviceModel
                                    
                                    if ($dbresult -eq $entry){$platformID = "Exists"}else{$platformID = "Missing"}

									[PSCustomObject]@{
                                    
                                    'HKCU DeviceCache ID' = $entry
                                    Type = $Type
                                    'Device Name' = $Name
                                    Make = $Make
                                    Model = $Model
                                    'DeviceID in dB' = $platformID
													}
                                }
# Display results           
$output|Out-GridView -PassThru -Title "There are ($RegCount) device IDs in HKCU and ($dbcount) in the: '$F'"
[gc]::Collect() 







