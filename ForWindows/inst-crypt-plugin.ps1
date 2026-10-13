# Please contact IBSurgeon with any question regarding this script: support@ib-aid.com
# This script is provided AS IS, without any warranty. 
# This script is licensed under IDPL https://firebirdsql.org/en/initial-developer-s-public-license-version-1-0/

# Location of crypt plugins
$ftp_url = "https://cc.ib-aid.com/download/distr/crypt"
# temp directory
$Global:tempDir = ""
# Service search criteria
$SearchTerm = "Firebird"  
# Array for holding service search results
#$Global:services = @()
$Global:services =[System.Collections.ArrayList]::new()
$Global:services_new = @()
# User specified path to FB installation
$Global:pathFB = ""

$searchKHText = "KeyHolderPlugin"
$insKHText = "KeyHolderPlugin = KeyHolder	# inserted by installer script"
$pathEmpDB = "db-crypt\employee.fdb"
# Collect services where Name or Path match criteria

function FindFBServices {
	Get-CimInstance -ClassName Win32_Service | ForEach-Object {
		if ($_.Name -like "*$SearchTerm*" -or $_.DisplayName -like "*$SearchTerm*")
		{
        		$Global:services.Add($_) | Out-Null
    		}
	}
}

function ValidateServices {
#	foreach ($s in $services) {
 	for ( $j = $services.Count-1; $j -ge 0; $j--) {
		$exe = GetExeNameByIndex $j
		$path = GetPathByIndex $j
		# does EXE really exist?
		$b1 = (-not (Test-Path $exe))
		# is there a crypt plugin?
		$b2 = (Test-Path "$path\plugins\dbcrypt.dll")
		# does path contain "hqbird"?
		$b3 = ($exe -match "hqbird")
		if ($b1 -or $b2 -or $b3) {
		#	$null
			$services.RemoveAt($j)
		}
	}
}

function GetExeNameByIndex {
	param ( $idx )
	
	# Special scenario if user specified path to FB installation
	if ($idx -eq -1) {
		$pathFBExe = "$pathFB\firebird.exe"
		if (Test-Path $pathFBExe) {
			return $pathFBExe
		} else {
			Write-Host "File $pathFBExe not found, exiting."
			exitScript 0
		}
	# Otherwise try to find firebird.exe from windows service info
	} else {
	        $exe  = $services[$idx].PathName
#		if ($exe -and (Test-Path $exe)) {
		if ($exe) {
        		if ($exe.Contains("`"")) {  # "
        			$exe = ($exe -split '"', 3)[1]
	       		} elseif ($exe.Contains(" ")) {	
        			$exe = ($exe -split " ", 3)[0]
       			} 
		        #Write-Host "Got exe name: $exe"
	        	return $exe
		} else {
			return -1	
		}
        }
}

function GetPathByIndex {
	param ( $idx )
	
	$exe = GetExeNameByIndex $idx
        $path = Split-Path -Path $exe
        return $path
}

function GetExeArchByIndex {
    param(
        [Parameter(Mandatory=$true)]
        $idx
    )
	$FilePath = GetExeNameByIndex $idx
    	if (-not (Test-Path $FilePath)) {
        	Write-Error "File not found: $FilePath"
	        return $null
	}
	try {
		$stream = [System.IO.File]::OpenRead($FilePath)
        	$reader = New-Object System.IO.BinaryReader($stream)
	        $signature = $reader.ReadUInt16()
	        if ($signature -ne 0x5A4D) {  # 'MZ'
	            Write-Error "Not an exe file (no MZ signature)"
	            return $null
	        }
	        $stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
		$peHeaderOffset = $reader.ReadUInt32()

	        $stream.Seek($peHeaderOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
	        $peSignature = $reader.ReadUInt32()
	        if ($peSignature -ne 0x00004550) {  # 'PE\0\0'
	            Write-Error "PE signature not found"
	            return $null
        	}
        # read machine (2 байта после "PE")
        $machine = $reader.ReadUInt16()
        # determine architecture
        $architecture = switch ($machine) {
#            0x014C { "x86" }      # Intel 386
#            0x8664 { "x64" }      # AMD64
            0x014C { "32bit" }      # Intel 386
            0x8664 { "64bit" }      # AMD64
            0x0200 { "IA64" }     # Intel Itanium
            0xAA64 { "ARM64" }    # ARM64
            default { "Unknown ($machine)" }
        }
        return $architecture
    }
    catch {
        Write-Error "Error reading file: $_"
        return $null
    }
    finally {
        $reader.Close()
        $stream.Close()
    }
}

function GetVersionByIndex{
	param ( $idx )
	
      	$exe = GetExeNameByIndex $idx
	if ($exe -and (Test-Path $exe)) {
 		$file = Get-Item $exe
		$version = $file.VersionInfo.ProductVersion
	        return $version
	} else {
		exitScript 1
	}
}

function ShowGreeting {
	Write-Host "This script will install Firebird crypt plugin."
	Write-Host "Now script will scan OS registry for Firebird installations."
	Write-Host "You can run script silently adding --crypt=`"c:\path\to\firebird`" parameter"
	Write-Host "(Do not forget double-quotes in path like `"C:\Program Files`", etc...)"
	Write-Host "Press Enter to continiue or Ctrl+C to exit script." -ForegroundColor Yellow
	Read-Host
}

function ShowMenu {
	$cnt = $services.Count
	Write-Host "== Choose from installed instances =="
	Write-Host "============= WARNING! =============="
	Write-Host "If you select service that is running"
	Write-Host "it will be restarted to install plugin"
	Write-Host " -------------------------------------"
	for ( $index = 0; $index -lt $cnt; $index++) {
		$name = "{0}) Service Name: {1} ({2}, {3})" -f $($index+1), $services[$index].Name, $services[$index].State, $services[$index].Status
		Write-Host $name
		$path = GetPathByIndex $index
	      	Write-Host "Installed in: $path"
		$version = GetVersionByIndex $index
		$arch = GetExeArchByIndex $index
	        Write-Host "Version: $version ($arch)"
		Write-Host " -------------------------------------"
	}
	Write-Host "0) Exit script"
	do {
		$choice = Read-Host "Enter number (0-$cnt) and press Enter"
#	} until ($choice -match "^[0-$cnt]$")
	} until ($choice -match '^\d+$' -and [int]$choice -le $cnt)
	return $choice
} # ShowMenu

function ExpandZipWithoutRoot {
    param(
        [string]$ZipFile,
        [string]$Destination,
        [switch]$Force
    )
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        Expand-Archive -Path $ZipFile -DestinationPath $tempDir -Force
        $rootFolder = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
        if ($rootFolder) {
            Get-ChildItem -Path $rootFolder.FullName | Copy-Item -Destination $Destination -Recurse -Force
        }
        else {
            Get-ChildItem -Path $tempDir | Copy-Item -Destination $Destination -Force
        }
    }
    finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} # ExpandZipWithoutRoot

function DownloadPluginByIndex {
	param ( $idx )
	
	$arch = GetExeArchByIndex $idx
	$str = GetVersionByIndex $idx
	$short_ver = $str.Substring(0, 1) + $str.Substring(2, 1)
	$plugin_name = "CryptPlugin-FB_{0}_WINDOWS_{1}.zip" -f $short_ver, $arch
	$url = $ftp_url + "/" + $plugin_name
	$output = $tempDir + "\plugin.zip"
	Write-Host "Downloading plugin... $url"
	try {
		# Invoke-WebRequest -Uri $url -OutFile $output
		Invoke-WebRequest -Uri $url -OutFile $output -Method Get -ErrorAction Stop
	}
	catch {
		throw "Error downloading $plugin_name : $($_.Exception.Message)"
    	}
	
	$src_dir = $tempDir + "\plugin"
	New-Item -ItemType Directory -Path $src_dir -Force | Out-Null
	Write-Host "Extracting plugin..."
	ExpandZipWithoutRoot -ZipFile $output -Destination $src_dir -Force
	$fb_conf = "$src_dir\Server\firebird.conf"
	if (Test-Path $fb_conf) {
		Remove-Item -Path $fb_conf -Force
	}
	
	$dst_path = GetPathByIndex $idx
	Write-Host "Copying plugin files to $dst_path"
	Copy-Item -Path "$src_dir\Server\*" -Destination $dst_path -Recurse -Force
	Copy-Item -Path "$src_dir\Server\plugins" -Destination $dst_path -Recurse -Force
} # DownloadPluginByIndex

function UpdateConfig {
	param ( $idx )

	$dst_path = GetPathByIndex $idx
	$fbConfPath = "$dst_path\firebird.conf"

	# Search firebird.conf for KeyHolder plugin
	$pattern = "^[^\#]*$searchKHText"
	if (Select-String -Path $fbConfPath -Pattern $pattern) {
		Write-Host "Parameter `"$searchKHText`" already presents in firebird.conf. Please, check it out."
	} else {
		copyFileWithDate -Path $fbConfPath
		Write-Host "Adding $searchKHText to firebird.conf"
		Add-Content -Path $fbConfPath -Value $insKHText
	}
}

function CreateTempDir {
	# Make temp directory
	$Global:tempDir = "$env:TEMP\temp-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss'))"
	New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

function AdjustRunTestsWait {
	# Vendor run-tests.ps1 pauses inside isql with "shell timeout /t 5 /nobreak".
	# timeout.exe cannot run with redirected stdin (CI jobs, scheduled runs), so the
	# wait is skipped and encryption is tested before the crypt thread completes.
	# Replace it with a ping-based sleep like the KeyHolderStdin section already uses.
	# No-op if the vendor zip already ships a fixed script.
	$rt = "$Global:clientRoot\db-crypt\run-tests.ps1"
	if (-not (Test-Path $rt)) { return }
	$text = [System.IO.File]::ReadAllText($rt)
	$patched = $text -replace 'shell timeout /t \d+ /nobreak\s*;', 'shell ping 127.0.0.1 -n 6 > nul;'
	if ($patched -ne $text) {
		[System.IO.File]::WriteAllText($rt, $patched)
		Write-Host "Adjusted encryption wait in run-tests.ps1 for non-interactive execution"
	}
}

function CopyClient {
	Write-Host "Copying client files..." -ForegroundColor Yellow
	$p = (Get-Location).Path

	$source = "$tempDir\plugin\Client"
	$destination = (Get-Location).Path + "\CryptClient"

	if (-not (Test-Path $destination)) {
	    New-Item -ItemType Directory -Path $destination -Force | Out-Null
	    Write-Host "Created directory $destination"
	}

	try {
		Copy-Item -Path "$source\*" -Destination $destination -Recurse -Force -ErrorAction Stop
		Write-Host "Client files successfully copied to $destination" -ForegroundColor Green
		$Global:dbCryptDir = "$destination\db-crypt"
		$Global:empPath = "$Global:dbCryptDir\employee.fdb"
		$Global:clientRoot = $destination
		Write-Host "DB copied to $empPath"
	} catch {
		throw "Failed to copy client files: $($_.Exception.Message)"
	}
}

function exitScript {
	param ( $code )
	# Remove temp directory on exit
	if ($tempDir) {
		if (Test-Path $tempDir) {
			Remove-Item -Path $tempDir -Recurse -Force
		}
	}
	exit $code
}

function TestMSVCRTPresence {
	try {
		$apps = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -like "Microsoft Visual C++*" } | Select-Object Name, Version
		$count = @($apps).Count
		if ($count -eq 0) {
			Write-Host "Script cannot find any MSVCRT installed, exiting..."
			Write-Host "Please, install appropriate version of Microsoft Visual C++ Redistributable:"
			Write-Host "https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170"
			exitScript 1
		}
		Write-Host "MSVCRT instances found: $count"
	} catch {
		Write-Host "Error retrieving MSVCRT list, exiting..."
		exitScript 1
	}
}

function testAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function copyFileWithDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [datetime]$Date = (Get-Date)
    )

    # check if file really exist
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Error "File not found: $Path"
        return
    }

    # if destination folder is not set, then copy to same folder
    if (-not $Destination) {
        $Destination = Split-Path -Parent $Path
    }

    # does file folder exist?
    if (-not (Test-Path -LiteralPath $Destination -PathType Container)) {
        Write-Error "Destination folder not found: $Destination"
        return
    }

    # parse file name
    $item      = Get-Item -LiteralPath $Path
    $baseName  = $item.BaseName      # name without extension
    $extension = $item.Extension     # extension with dot (may be empty)

    # create suffix with date stamp
    $dateSuffix = $Date.ToString("yyyy-MM-dd_HHmmss")

    # create new file name: filename.ext.yyyy-MM-dd_HHmmss
    if ($extension) {
        $newName = "$baseName$extension.$dateSuffix"
    } else {
        $newName = "$baseName.$dateSuffix"
    }
    $newPath = Join-Path -Path $Destination -ChildPath $newName
    # do copy
    try {
        Copy-Item -LiteralPath $Path -Destination $newPath -ErrorAction Stop
        Write-Host "$Path -> $newPath copied"
        return $newPath
    }
    catch {
        Write-Error "Error copying: $($_.Exception.Message)"
    }
}


# Main script section

if (-not (testAdmin)) {
	Write-Host "This script must be run with administrative privileges."
	exitScript 1
}

if ($args.Count -gt 0) {
	foreach ($arg in $args) {
	    if ($arg -match '^--(.+?)=(.*)') {
	        $key = $matches[1]
	        $value = $matches[2]
	        if ($key -eq "crypt") {
	        	Write-Host "Searching for Firebird installation in $value"
	        	$pathFB = $value
			CreateTempDir
			DownloadPluginByIndex -1
			UpdateConfig -1
			exitScript 0
	        } else {
	        	Write-Host "Unknown parameter received ($key)"
	        }
	    }
	}
	
} else {
	ShowGreeting
	FindFBServices
	ValidateServices
#	TestMSVCRTPresence

#	leave this as special scenario for only one
#	instance available for applying crypt plugin
#	if ($services.Count -gt 1) {
	if ($services.Count -gt 0) {
		$r = ShowMenu
		if ($r -eq 0) {
			exitScript 0
		} else {
			if ($services[$r-1].State -eq "Running") {
				# Firebird service is running, let's try to stop it
				Write-Host "Service `"$($services[$r-1].Name)`" is running, stopping..."
				Stop-Service -Name $($services[$r-1].Name) -Force -ErrorAction Stop
			}
			$errorOccured = 0
			try {
				CreateTempDir
				DownloadPluginByIndex $($r-1)
				CopyClient
				AdjustRunTestsWait
				UpdateConfig $($r-1)
			}
			catch {
				Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
				$errorOccured = 1
				
			}
			finally {
				# Start Firebird service in any case
				Write-Host "Starting `"$($services[$r-1].Name)`"..."
				Start-Service -Name $($services[$r-1].Name) -ErrorAction Stop
			}
			if ($errorOccured -eq 1) {
				Write-Host "Skipping tests because installation failed." -ForegroundColor Yellow
				exitScript 1
			}
			Write-Host "Running tests: $Global:clientRoot\db-crypt\run-tests.ps1"
			& "$Global:clientRoot\db-crypt\run-tests.ps1"
			if ($LASTEXITCODE -ne 0) {
				Write-Host "Tests failed (exit code $LASTEXITCODE)" -ForegroundColor Red
				exitScript 1
			}
			exitScript 0
		}
#	end of special scenario
#	} elseif ($services.Count -eq 1){
#		CreateTempDir
#		DownloadPluginByIndex 0
	} else {
	    Write-Host "Firebird instances available for plugin installation were not found" -ForegroundColor Yellow
	    Write-Host "If you have Firebird installation and still want to install crypt plugin"
	    Write-Host "run script again adding parameter --crypt=c:\path\to\firebird\installation"
	    Write-Host "e.g. inst-crypt-plugin.ps1 --crypt='c:\program Files\Firebird\Firebird_3_0'"
	    Write-Host "Warning: You must stop Firebird service before this and start it again after install"
	}
	exitScript 0
}
