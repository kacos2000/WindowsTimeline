<#
	.SYNOPSIS
		Extracts Clipboard Text entries from ActivitiesCache.db & wal
	
	.DESCRIPTION
		Extracts Clipboard Text entries from ActivitiesCache.db & wal files 
		in the Selected folder and subfolders.
		A separate CSV will be created for each file

	.PARAMETER InputFolder
		The Folder where ActivitiesCache.db & wal files are located
	
	.PARAMETER Outpath
		The Folder where a new folder with the output 
		CSV(s) will be saved.

	.EXAMPLE
		PS C:\> .\Clippy2csv.ps1 -InputFolder C:\Users\username\AppData\Local\ConnectedDevicesPlatform -Outpath C:\Users\username\Desktop
	
	.NOTES
		Original Script Name: Clippy2csv.ps1
		Version: 1.0
		Author:  Costas Katsavounidis
		Signed:  19/01/2023

	.LINK
		https://github.com/kacos2000/WindowsTimeline/blob/master/README.md
		https://github.com/kacos2000/WindowsTimeline

#>

[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true,
			   Position = 0)]
	[System.String]$InputFolder,
	[Parameter(Mandatory = $true,
			   Position = 1)]
	[System.String]$Outpath
)

# if ($null = $InputFolder) { $InputFolder = "$([Environment]::GetFolderPath('LocalApplicationData'))\ConnectedDevicesPlatform" }
# if ($null = $Outpath) { $Outpath = [Environment]::GetFolderPath('Desktop') }



function get-files
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[System.String]$Folder
	)
	
	try
	{
		$dirFiles = [System.IO.Directory]::GetFiles($Folder, "*", 'AllDirectories').Where{ $_ -match 'ActivitiesCache.db' -and $_ -notmatch 'ActivitiesCache.db-shm' }
		# Get File Properties
		$files = @(foreach ($file in $dirFiles)
			{
				[System.Windows.Forms.Application]::DoEvents()
				
				# Replace known AppID with it's Name
				$fname = Split-Path -Path $file -leaf
				
				[PSCustomObject][Ordered]@{
					'FileName' = $file
					'Name'	   = $fname
					'Parent'   = (Split-Path -Path $file -Parent).TrimStart("$($Folder)")
					'CreationTimeUtc' = [system.IO.File]::GetCreationTimeUtc($file).ToString("dd/MM/yyyy HH:mm:ss.fffffff")
					'LastAccessTimeUtc' = [system.IO.File]::GetLastAccessTimeUtc($file).ToString("dd/MM/yyyy HH:mm:ss.fffffff")
					'LastWriteTimeUtc' = [system.IO.File]::GetLastWriteTimeUtc($file).ToString("dd/MM/yyyy HH:mm:ss.fffffff")
					'Attributes' = [system.IO.File]::GetAttributes($file)
					'Size'	   = [System.IO.FileInfo]::new($file).Length
				}
				
			} # end for each
		)
	} # end try
	catch { $files = $null }
	
	if ($files.Count -eq 0)
	{
		[System.Console]::Beep(500, 150)
		
	}
	else
	{
		return $files
	}
}

function readfile
{
	param
	(
		[Parameter(Mandatory = $true)]
		$InputFile
	)
	
	$script:clipText = $null
	
	if (![string]::IsNullOrEmpty($InputFile))
	{
		# Read Contents
		try
		{
			$Stream = New-Object System.IO.FileStream -ArgumentList $InputFile.Filename, 'Open', 'Read', 'ReadWrite'
			$Encoding = [System.Text.Encoding]::GetEncoding(28591)
			$StreamReader = New-Object IO.StreamReader -ArgumentList $Stream, $Encoding
			$Clipcontent = $StreamReader.ReadToEnd()
			$StreamReader.Close()
			$StreamReader.Dispose()
			$Stream.Close()
			$Stream.Dispose()
			[gc]::Collect()
		}
		catch { $Clipcontent = $null }
		
		if (![string]::IsNullOrEmpty($Clipcontent))
		{
			# Read File Signature
			$sig = $Clipcontent.substring(0, 16)
			$walb = [System.Text.Encoding]::getencoding(28591).GetBytes($Clipcontent.substring(4, 4))
			$walformatversion = [System.BitConverter]::ToString($walb) -replace '-', ''
			if ($sig -match "SQLite format 3")
			{ Write-Host  "$($InputFile.Filename) is SQLite format 3" }
			elseif ($walformatversion -eq "002DE218")
			{ Write-Host  "$($InputFile.Filename) is WAL format version: 3007000" }
			else
			{
				$status2.Text = "$($InputFile.Filename) is not SQLite3 or WAL"
				[System.Console]::Beep(600, 150)
				return
			}
			
			#Regex pattern for Clipboard entries
			[regex]$patternTXT = '(\[\{\"content\"\:\").+?(\"\,\"formatName\"\:\"Text\"\}\])'
			#	[regex]$patternHTML = '(\[\{\"content\"\:\").+?(\"\,\"formatName\"\:\"HTML\"\}\])'
			#	[regex]$patternIMG = '(\[\{\"content\"\:\").+?(\"\,\"formatName\"\:\"Image\"\}\])'
			
			#Search results
			$script:clipdata = $patternTXT.Matches($Clipcontent)
			$count = $clipdata.value.Count
			
			# Extract & Convert clipboard text
			$script:clipText = if ($Count -ge 1)
			{
				write-host "Total Clipboard Text entries found: $($Count)"
				$c = 0
				foreach ($entry in $clipdata)
				{
					$c++
					try { $text = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($entry.value | ConvertFrom-Json).content)) }
					catch [System.ArgumentException] { Write-Host "Error at offset $($entry.Index)"; $text = $null }
					catch { Write-Host "Error at offset $($entry.Index)"; $text = $null }
					finally { $Error.Clear() }
					if (![string]::IsNullOrEmpty($text))
					{
						[PSCustomObject]@{
							Entry		   = $c
							"Offset_(Dec)" = $entry.Index
							"Offset_(Hex)" = '0x{0:X8}' -f $entry.Index
							"Length_(B64)" = if ($entry.length -gt 36) { $entry.length - 36 }else{ $null }
							Copied_Text    = $text
						}
					}
				}
			}
			else
			{
				Write-host "No Clipboard Text entries found in $($InputFile.Filename)"
				[System.Console]::Beep(600, 150)
			}
		}
		else
		{
			Write-host "Nothing to read in $($InputFile.Filename)"
			[System.Console]::Beep(600, 150)
			return
		}
	}
	else { Write-Host "No File selected"; return }
} # end function readfile

if (!!$InputFolder -and !!(Test-Path -Path $InputFolder) -and !!$Outpath)
{
	# Create Output Directory
	$snow = Get-Date -Format "ddMMMyyyy-HHmmss"
	$Outpath = $Outpath + "\ClipboardText_$($snow)"
	$null = [System.IO.Directory]::CreateDirectory("$($Outpath)")
	Start-Transcript -OutputDirectory $Outpath
	$c=1
	foreach ($file in (get-files -Folder $InputFolder.trim('"').trim("'")))
	{
		readfile -InputFile $file
		if ($script:clipText.count -ge 1)
		{
			$ext = [System.IO.FileInfo]::new($file.name).Extension.TrimStart('.')
			Write-Host "Saving Clipboard contents of:" -NoNewline
			$file | select -Property FileName, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc, Attributes, Size | Out-String
			$filename = "$($file.Parent)_ClipboardTextHistory-$($ext)"
			if ([System.IO.File]::Exists("$($Outpath)\$($filename).csv"))
			{
				$filename = "$($filename)_$($c)"
			}
			$script:clipText | Export-Csv -Delimiter "|" -Encoding UTF8 -Path "$($Outpath)\$($filename).csv" -NoTypeInformation
		}
	$c++	
	}
	Stop-Transcript
}





# SIG # Begin signature block
# MIIviAYJKoZIhvcNAQcCoIIveTCCL3UCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAM3bd8uSdY02Ia
# GuqlP79AlZjMgZMHMBZKb471u4VGk6CCKI0wggQyMIIDGqADAgECAgEBMA0GCSqG
# SIb3DQEBBQUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQIDBJHcmVhdGVyIE1hbmNo
# ZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoMEUNvbW9kbyBDQSBMaW1p
# dGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2VydmljZXMwHhcNMDQwMTAx
# MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFD
# b21vZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZp
# Y2VzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvkCd9G7h6naHHE1F
# RI6+RsiDBp3BKv4YH47kAvrzq11QihYxC5oG0MVwIs1JLVRjzLZuaEYLU+rLTCTA
# vHJO6vEVrvRUmhIKw3qyM2Di2olV8yJY897cz++DhqKMlE+faPKYkEaEJ8d2v+PM
# NSyLXgdkZYLASLCokflhn3YgUKiRx2a163hiA1bwihoT6jGjHqCZ/Tj29icyWG8H
# 9Wu4+xQrr7eqzNZjX3OM2gWZqDioyxd4NlGs6Z70eDqNzw/ZQuKYDKsvnw4B3u+f
# mUnxLd+sdE0bmLVHxeUp0fmQGMdinL6DxyZ7Poolx8DdneY1aBAgnY/Y3tLDhJwN
# XugvyQIDAQABo4HAMIG9MB0GA1UdDgQWBBSgEQojPpbxB+zirynvgqV/0DCktDAO
# BgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zB7BgNVHR8EdDByMDigNqA0
# hjJodHRwOi8vY3JsLmNvbW9kb2NhLmNvbS9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2Vz
# LmNybDA2oDSgMoYwaHR0cDovL2NybC5jb21vZG8ubmV0L0FBQUNlcnRpZmljYXRl
# U2VydmljZXMuY3JsMA0GCSqGSIb3DQEBBQUAA4IBAQAIVvwC8Jvo/6T61nvGRIDO
# T8TF9gBYzKa2vBRJaAR26ObuXewCD2DWjVAYTyZOAePmsKXuv7x0VEG//fwSuMdP
# WvSJYAV/YLcFSvP28cK/xLl0hrYtfWvM0vNG3S/G4GrDwzQDLH2W3VrCDqcKmcEF
# i6sML/NcOs9sN1UJh95TQGxY7/y2q2VuBPYb3DzgWhXGntnxWUgwIWUDbOzpIXPs
# mwOh4DetoBUYj/q6As6nLKkQEyzU5QgmqyKXYPiQXnTUoppTvfKpaOCibsLXbLGj
# D56/62jnVvKu8uMrODoJgbVrhde+Le0/GreyY+L1YiyC1GoAQVDxOYOflek2lphu
# MIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0BAQwFADB7
# MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYD
# VQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEhMB8GA1UE
# AwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAwMFoXDTI4
# MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
# aXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5nIFJvb3Qg
# UjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIEJHQu/xYj
# ApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7fbu2ir29
# BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGrYbNzszwL
# DO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTHqi0Eq8Nq
# 6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv64IplXCN
# /7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2JmRCxrds+
# LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0POM1nqFOI
# +rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXybGWfv1Vb
# HJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyheBe6QTHrn
# xvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXycuu7D1fkK
# dvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7idFT/+IAx1
# yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQYMBaAFKAR
# CiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJwIDaRXBeF
# 5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUEDDAKBggr
# BgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmljYXRlU2Vy
# dmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3SamES4aUa1
# qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+BtlcY2fU
# QBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8ZsBRNraJ
# AlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx2jLsFeSm
# TD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyoXZ3JHFuu
# 2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p1FiAhORF
# e1rYMIIFgzCCA2ugAwIBAgIORea7A4Mzw4VlSOb/RVEwDQYJKoZIhvcNAQEMBQAw
# TDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjYxEzARBgNVBAoTCkds
# b2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMTQxMjEwMDAwMDAwWhcN
# MzQxMjEwMDAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBS
# NjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH6HPKZvnsFMp7PPcNCPG0RQss
# grRIxutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay/xTOURQh7ErdG1rG1ofuTToV
# Bu1kZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025eShNUhqKGoC3GYEOfsSKvGRM
# IRxDaNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qjuL++gmNQ0PAYid/kD3n16qIf
# KtJwLnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0pPbzlUoSB239jLKJz9CgYXfI
# WHSw1CM69106yqLbnQneXUQtkPGBzVeS+n68UARjNN9rkxi+azayOeSsJDa38O+2
# HBNXk7besvjihbdzorg1qkXy4J02oW9UivFyVm4uiMVRQkQVlO6jxTiWm05OWgtH
# 8wY2SXcwvHE35absIQh1/OZhFj931dmRl4QKbNQCTXTAFO39OfuD8l4UoQSwC+n+
# 7o/hbguyCLNhZglqsQY6ZZZZwPA1/cnaKI0aEYdwgQqomnUdnjqGBQCe24DWJfnc
# BZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQULHpYT9NLCEnFlWQaYw55PfWz
# jMpYrZxCRXluDocZXFSxZba/jJvcE+kNb7gu3GduyYsRtYQUigAZcIN5kZeR1Bon
# vzceMgfYFGM8KEyvAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8E
# BTADAQH/MB0GA1UdDgQWBBSubAWjkxPioufi1xzWx/B/yGdToDAfBgNVHSMEGDAW
# gBSubAWjkxPioufi1xzWx/B/yGdToDANBgkqhkiG9w0BAQwFAAOCAgEAgyXt6NH9
# lVLNnsAEoJFp5lzQhN7craJP6Ed41mWYqVuoPId8AorRbrcWc+ZfwFSY1XS+wc3i
# EZGtIxg93eFyRJa0lV7Ae46ZeBZDE1ZXs6KzO7V33EByrKPrmzU+sQghoefEQzd5
# Mr6155wsTLxDKZmOMNOsIeDjHfrYBzN2VAAiKrlNIC5waNrlU/yDXNOd8v9EDERm
# 8tLjvUYAGm0CuiVdjaExUd1URhxN25mW7xocBFymFe944Hn+Xds+qkxV/ZoVqW/h
# pvvfcDDpw+5CRu3CkwWJ+n1jez/QcYF8AOiYrg54NMMl+68KnyBr3TsTjxKM4kEa
# SHpzoHdpx7Zcf4LIHv5YGygrqGytXm3ABdJ7t+uA/iU3/gKbaKxCXcPu9czc8FB1
# 0jZpnOZ7BN9uBmm23goJSFmH63sUYHpkqmlD75HHTOwY3WzvUy2MmeFe8nI+z1TI
# vWfspA9MRf/TuTAjB0yPEL+GltmZWrSZVxykzLsViVO6LAUP5MSeGbEYNNVMnbrt
# 9x+vJJUEeKgDu+6B5dpffItKoZB0JaezPkvILFa9x8jvOOJckvB595yEunQtYQEg
# fn7R8k8HWV+LLUNS60YMlOH1Zkd5d9VUWx+tJDfLRVpOoERIyNiwmcUVhAn21klJ
# wGW45hpxbqCo8YLoRT5s1gLXCmeDBVrJpBAwggYaMIIEAqADAgECAhBiHW0MUgGe
# O5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTla
# MFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNV
# BAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqG
# SIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNs
# fvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFi
# gOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09
# fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmT
# nAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp
# 4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8
# rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ
# 1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh
# 2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaA
# FDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritUpimq
# F6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1Ud
# HwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUF
# BzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2ln
# bmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdv
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aV
# cdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWT
# syNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+
# w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWD
# RF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfC
# ipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJszkye
# iaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z76mKn
# zAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGv
# spbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95E
# jza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6
# SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo
# 2bC5a4CH2RwwggZZMIIEQaADAgECAg0B7BySQN79LkBdfEd0MA0GCSqGSIb3DQEB
# DAUAMEwxIDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQK
# EwpHbG9iYWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTE4MDYyMDAwMDAw
# MFoXDTM0MTIxMDAwMDAwMFowWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2Jh
# bFNpZ24gbnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENB
# IC0gU0hBMzg0IC0gRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDw
# AuIwI/rgG+GadLOvdYNfqUdSx2E6Y3w5I3ltdPwx5HQSGZb6zidiW64HiifuV6PE
# Ne2zNMeswwzrgGZt0ShKwSy7uXDycq6M95laXXauv0SofEEkjo+6xU//NkGrpy39
# eE5DiP6TGRfZ7jHPvIo7bmrEiPDul/bc8xigS5kcDoenJuGIyaDlmeKe9JxMP11b
# 7Lbv0mXPRQtUPbFUUweLmW64VJmKqDGSO/J6ffwOWN+BauGwbB5lgirUIceU/kKW
# O/ELsX9/RpgOhz16ZevRVqkuvftYPbWF+lOZTVt07XJLog2CNxkM0KvqWsHvD9WZ
# uT/0TzXxnA/TNxNS2SU07Zbv+GfqCL6PSXr/kLHU9ykV1/kNXdaHQx50xHAotIB7
# vSqbu4ThDqxvDbm19m1W/oodCT4kDmcmx/yyDaCUsLKUzHvmZ/6mWLLU2EESwVX9
# bpHFu7FMCEue1EIGbxsY1TbqZK7O/fUF5uJm0A4FIayxEQYjGeT7BTRE6giunUln
# EYuC5a1ahqdm/TMDAd6ZJflxbumcXQJMYDzPAo8B/XLukvGnEt5CEk3sqSbldwKs
# DlcMCdFhniaI/MiyTdtk8EWfusE/VKPYdgKVbGqNyiJc9gwE4yn6S7Ac0zd0hNkd
# Zqs0c48efXxeltY9GbCX6oxQkW2vV4Z+EDcdaxoU3wIDAQABo4IBKTCCASUwDgYD
# VR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOoWxmnn
# 48tXRTkzpPBAvtDDvWWWMB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1Og
# MD4GCCsGAQUFBwEBBDIwMDAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2Jh
# bHNpZ24uY29tL3Jvb3RyNjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmds
# b2JhbHNpZ24uY29tL3Jvb3QtcjYuY3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIG
# CCsGAQUFBwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5
# LzANBgkqhkiG9w0BAQwFAAOCAgEAf+KI2VdnK0JfgacJC7rEuygYVtZMv9sbB3DG
# +wsJrQA6YDMfOcYWaxlASSUIHuSb99akDY8elvKGohfeQb9P4byrze7AI4zGhf5L
# FST5GETsH8KkrNCyz+zCVmUdvX/23oLIt59h07VGSJiXAmd6FpVK22LG0LMCzDRI
# RVXd7OlKn14U7XIQcXZw0g+W8+o3V5SRGK/cjZk4GVjCqaF+om4VJuq0+X8q5+dI
# ZGkv0pqhcvb3JEt0Wn1yhjWzAlcfi5z8u6xM3vreU0yD/RKxtklVT3WdrG9KyC5q
# ucqIwxIwTrIIc59eodaZzul9S5YszBZrGM3kWTeGCSziRdayzW6CdaXajR63Wy+I
# Lj198fKRMAWcznt8oMWsr1EG8BHHHTDFUVZg6HyVPSLj1QokUyeXgPpIiScseeI8
# 5Zse46qEgok+wEr1If5iEO0dMPz2zOpIJ3yLdUJ/a8vzpWuVHwRYNAqJ7YJQ5NF7
# qMnmvkiqK1XZjbclIA4bUaDUY6qD6mxyYUrJ+kPExlfFnbY8sIuwuRwx773vFNgU
# QGwgHcIt6AvGjW2MtnHtUiH+PvafnzkarqzSL3ogsfSsqh3iLRSd+pZqHcY8yvPZ
# HL9TTaRHWXyVxENB+SXiLBB+gfkNlKd98rUJ9dhgckBQlSDUQ0S++qCV5yBZtnjG
# pGqqIpswggZoMIIEUKADAgECAhABSJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEB
# CwUAMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEw
# LwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0
# MB4XDTIyMDQwNjA3NDE1OFoXDTMzMDUwODA3NDE1OFowYzELMAkGA1UEBhMCQkUx
# GTAXBgNVBAoMEEdsb2JhbFNpZ24gbnYtc2ExOTA3BgNVBAMMMEdsb2JhbHNpZ24g
# VFNBIGZvciBNUyBBdXRoZW50aWNvZGUgQWR2YW5jZWQgLSBHNDCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAMLJ3AO2G1D6Kg3onKQh2yinHfWAtRJ0I/5e
# L8MaXZayIBkZUF92IyY1xiHslO+1ojrFkIGbIe8LJ6TjF2Q72pPUVi8811j5bazA
# L5B4I0nA+MGPcBPUa98miFp2e0j34aSm7wsa8yVUD4CeIxISE9Gw9wLjKw3/QD4A
# QkPeGu9M9Iep8p480Abn4mPS60xb3V1YlNPlpTkoqgdediMw/Px/mA3FZW0b1XRF
# OkawohZ13qLCKnB8tna82Ruuul2c9oeVzqqo4rWjsZNuQKWbEIh2Fk40ofye8eEa
# VNHIJFeUdq3Cx+yjo5Z14sYoawIF6Eu5teBSK3gBjCoxLEzoBeVvnw+EJi5obPrL
# TRl8GMH/ahqpy76jdfjpyBiyzN0vQUAgHM+ICxfJsIpDy+Jrk1HxEb5CvPhR8toA
# Ar4IGCgFJ8TcO113KR4Z1EEqZn20UnNcQqWQ043Fo6o3znMBlCQZQkPRlI9Lft3L
# bbwbTnv5qgsiS0mASXAbLU/eNGA+vQIDAQABo4IBnjCCAZowDgYDVR0PAQH/BAQD
# AgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBRba3v0cHQIwQ0q
# yO/xxLlA0krG/TBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIB
# FiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAMBgNVHRMB
# Af8EAjAAMIGQBggrBgEFBQcBAQSBgzCBgDA5BggrBgEFBQcwAYYtaHR0cDovL29j
# c3AuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0MEMGCCsGAQUFBzAC
# hjdodHRwOi8vc2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RzYWNhc2hh
# Mzg0ZzQuY3J0MB8GA1UdIwQYMBaAFOoWxmnn48tXRTkzpPBAvtDDvWWWMEEGA1Ud
# HwQ6MDgwNqA0oDKGMGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2Fj
# YXNoYTM4NGc0LmNybDANBgkqhkiG9w0BAQsFAAOCAgEALms+j3+wsGDZ8Z2E3JW2
# 318NvyRR4xoGqlUEy2HB72Vxrgv9lCRXAMfk9gy8GJV9LxlqYDOmvtAIVVYEtuP+
# HrvlEHZUO6tcIV4qNU1Gy6ZMugRAYGAs29P2nd7KMhAMeLC7VsUHS3C8pw+rcryN
# y+vuwUxr2fqYoXQ+6ajIeXx2d0j9z+PwDcHpw5LgBwwTLz9rfzXZ1bfub3xYwPE/
# DBmyAqNJTJwEw/C0l6fgTWolujQWYmbIeLxpc6pfcqI1WB4m678yFKoSeuv0lmt/
# cqzqpzkIMwE2PmEkfhGdER52IlTjQLsuhgx2nmnSxBw9oguMiAQDVN7pGxf+LCue
# 2dZbIjj8ZECGzRd/4amfub+SQahvJmr0DyiwQJGQL062dlC8TSPZf09rkymnbOfQ
# MD6pkx/CUCs5xbL4TSck0f122L75k/SpVArVdljRPJ7qGugkxPs28S9Z05LD7Mtg
# Uh4cRiUI/37Zk64UlaiGigcuVItzTDcVOFBWh/FPrhyPyaFsLwv8uxxvLb2qtuto
# I/DtlCcUY8us9GeKLIHTFBIYAT+Eeq7sR2A/aFiZyUrCoZkVBcKt3qLv16dVfLyE
# G02Uu45KhUTZgT2qoyVVX6RrzTZsAPn/ct5a7P/JoEGWGkBqhZEcr3VjqMtaM7WU
# M36yjQ9zvof8rzpzH3sg23IwggZyMIIE2qADAgECAhALYufvMdbwtA/sWXrOPd+k
# MA0GCSqGSIb3DQEBDAUAMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdv
# IExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBD
# QSBSMzYwHhcNMjIwMjA3MDAwMDAwWhcNMjUwMjA2MjM1OTU5WjB2MQswCQYDVQQG
# EwJHUjEdMBsGA1UECAwUS2VudHJpa8OtIE1ha2Vkb27DrWExIzAhBgNVBAoMGkth
# dHNhdm91bmlkaXMgS29uc3RhbnRpbm9zMSMwIQYDVQQDDBpLYXRzYXZvdW5pZGlz
# IEtvbnN0YW50aW5vczCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIxd
# u9+Lc83wVLNDuBn9NzaXp9JzWaiQs6/uQ6fbCUHC4/2lLfKzOUus3e76lSpnmo7b
# kCLipjwZH+yqWRuvrccrfZCoyVvBAuzdE69AMR02Z3Ay5fjN6kWPfACkgLe4D9og
# SDh/ZsOfHD89+yKKbMqsDdj4w/zjIRwcYGgBR6QOGP8mLAIKH7TwvoYBauLlb6aM
# /eG/TGm3cWd4oonwjiYU2fDkhPPdGgCXFem+vhuIWoDk0A0OVwEzDFi3H9zdv6hB
# bv+d37bl4W81zrm42BMC9kWgiEuoDUQeY4OX2RdNqNtzkPMI7Q93YlnJwitLfSrg
# GmcU6fiE0vIW3mkf7mebYttI7hJVvqt0BaCPRBhOXHT+KNUvenSXwBzTVef/9h70
# POF9ZXbUhTlJJIHJE5SLZ2DvjAOLUvZuvo3bGJIIASHnTKEIVLCUwJB77NeKsgDx
# YGDFc2OQiI9MuFWdaty4B0sXQMj+KxZTb/Q0O850xkLIbQrAS6T2LKEuviE6Ua7b
# QFXi1nFZ+r9XjOwZQmQDuKx2D92AUR/qwcpIM8tIbJdlNzEqE/2wwaE10G+sKuX/
# SaJFZbKXqDMqJr1fw0M9n0saSTX1IZrlrEcppDRN+OIdnQL3cf6PTqv1PTS4pZ/9
# m7iweMcU4lLJ7L/8ZKiIb0ThD9kIddJ5coICzr/hAgMBAAGjggGcMIIBmDAfBgNV
# HSMEGDAWgBQPKssghyi47G9IritUpimqF6TNDDAdBgNVHQ4EFgQUidoax6lNhMBv
# wMAg4rCjdP30S8QwDgYDVR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMwEQYJYIZIAYb4QgEBBAQDAgQQMEoGA1UdIARDMEEwNQYM
# KwYBBAGyMQECAQMCMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20v
# Q1BTMAgGBmeBDAEEATBJBgNVHR8EQjBAMD6gPKA6hjhodHRwOi8vY3JsLnNlY3Rp
# Z28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2LmNybDB5BggrBgEF
# BQcBAQRtMGswRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2Vj
# dGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAG+2x4Vn8dk+Y
# w0Khv6CZY+/QKXW+aG/siN+Wn24ijKmvbjiNEbEfCicwZ12YpkOCnuFtrXs8k9zB
# PusV1/wdH+0buzzSuCmkyx5v4wSqh8OsyWIyIsW/thnTyzYys/Gw0ep4RHFtbNTR
# K4+PowRHW1DxOjaxJUNi9sbNG1RiDSAVkGAnHo9m+wAK6WFOIFV5vAbCp8upQPwh
# aGo7u2hXP/d18mf/4BtQ+J7voX1BFwgCLhlrho0NY8MgLGuMBcu5zw07j0ZFBvyr
# axDPVwDoZw07JM018c2Nn4hg2XbYyMtUkvCi120uI6299fGs6Tmi9ttP4c6pubs4
# TY40jVxlxxnqqvIA/wRYXpWOe5Z3n80OFEatcFtzLrQTyO9Q1ptk6gso/RNpRu3r
# ug+aXqfvP3a32FNZAQ6dUGr0ae57OtgM+hlLMhSSyhugHrnbi9oNAsqa/KA6UtD7
# MxWJIwAqACTqqVjUTKjzaaE+12aS3vaO6tEqCuT+DOtu7aJRPnyyMYIGUTCCBk0C
# AQEwaDBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSsw
# KQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2AhALYufv
# MdbwtA/sWXrOPd+kMA0GCWCGSAFlAwQCAQUAoEwwGQYJKoZIhvcNAQkDMQwGCisG
# AQQBgjcCAQQwLwYJKoZIhvcNAQkEMSIEIPh896/4UPlzw3lMMjKfGb5SeuHzVTYo
# JIY0eOiCaHVuMA0GCSqGSIb3DQEBAQUABIICAFW2c46unGSutnoeD1N6ELdbfWt9
# n940h39hAjlmFzI13LKhoDvmVjvsQpeBRLp39XJYEyhiCV7VV1Vhq1epqYiWD2A2
# 05WqufvZyImWG9yyalwW0IlS6Eb1ahkZfeFvXPSup2yJmjQhyS9ny115UY3lUJbH
# lcb3mhejjosO+6L+ew/g29x+QwHzaGKrR/r7b0fnBM1i6UKvtGzfFwML1Y5onB6E
# CrKqCM7Pd3J0V4DOXPcgfw68m8DreCaLKD9rMquNUEabKBNO25sXboKupXEL/weW
# chzWDa7zr1Qzc15hVDtGtrjBnCHvMsCEp1T3aZAMqEz18/0kzhIqMebwQOe6rhjG
# IHb9D/VGnCkch+tJi4U/JvgIeoATcOhP/H2BdS9GDA1R82LrvCDDJRoUkIENW4Mb
# nl9n27I8ekTGd8G7nonN2qb9xeMUz+IUY4nlgP4e22eNxvQtzOifd6GOiQwtw/kH
# qrMmtZ7J1SKIO1h79hvIloJ9MHnWrza8g6WuvGeBJ/oj9d9MC+Yo0YzucX3hJNDP
# aIAknfmcf6A8vwtDFcbpC3ovNQAj5BBl+QebwWhxKfWjuVMmFRWkTovgFD3U54lH
# s56wfA94C8yn4jIS8EYRD6DquU/13hkkZCzjA9Nu9bZFKjB+BuP8p2FU5BNT6d+m
# BN+WAS+NXNjtqCWloYIDbDCCA2gGCSqGSIb3DQEJBjGCA1kwggNVAgEBMG8wWzEL
# MAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAvBgNVBAMT
# KEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQCEAFIkD3C
# irynoRlNDBxXuCkwCwYJYIZIAWUDBAIBoIIBPTAYBgkqhkiG9w0BCQMxCwYJKoZI
# hvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMzAxMTkwNDM3MzBaMCsGCSqGSIb3DQEJ
# NDEeMBwwCwYJYIZIAWUDBAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3DQEJBDEi
# BCCp+rCagj32f/LPvGtuJmImR1+viMMgqYklkpC3kt2lDjCBpAYLKoZIhvcNAQkQ
# AgwxgZQwgZEwgY4wgYsEFDEDDhdqpFkuqyyLregymfy1WF3PMHMwX6RdMFsxCzAJ
# BgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhH
# bG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhABSJA9woq8
# p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUABIIBgD4MAlkHneN0VZzr1Z0f43hGBaZ1
# uSm96NEdBYp/NI7PFbPnt0f3NuH2L/vXEPxeV3JuDLxxazvSiE4gGL36VhvTSEXR
# pSm70Q5swjwlD5XhAGRn77SgHEo1/haXpiPh3kbL3rH1ereg0/VUvWkPcIBR9Sc1
# z7RFrh3A9UHcoVeSzvqho8KAwrJ42ZSFMXM9reDjP4jyTHV2LxKGjCqhQ4h9Wj9E
# awZt8Ivk6XQZpZH04LQlUB0hVGvqX2EQyGRstegxYb46+A5htYCMKd5pa7vpUbL1
# +GiAZWRDHYCaCLRBuc8HpPbUtbS1Ne/8xqwySA1uS8N4LMaBYvdgu+ib33XcICuU
# 2Xuvr4jJhNNgo/M4cHrxVn8aATnbCFItCr8/gkM4R8BfKuJAUE1Mk4G58uDwtjhj
# Ck4JlskXJKh5tedsYua3yvQf+624Fmna/WMfEOogD5vCo/AohPdfy3BnuhA3j11D
# pk/fQtC0iWZ30u9sbtEf1whmHscQ+lZnC3Bbkw==
# SIG # End signature block
