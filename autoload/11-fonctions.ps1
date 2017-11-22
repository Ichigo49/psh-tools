function Get-DiskFree {
	[CmdletBinding()]
	param
	(
		[Parameter(Position = 0,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true)]
		[Alias('hostname')]
		[Alias('cn')]
		[string[]]$ComputerName = $env:COMPUTERNAME,
		
		[Parameter(Position = 1,
				   Mandatory = $false)]
		[Alias('runas')]
		[System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,
		[Parameter(Position = 2)]
		[switch]$Format
	)
	
	BEGIN
	{
		function Format-HumanReadable
		{
			param ($size)
			switch ($size)
			{
				{ $_ -ge 1PB }{ "{0:#.#'P'}" -f ($size / 1PB); break }
				{ $_ -ge 1TB }{ "{0:#.#'T'}" -f ($size / 1TB); break }
				{ $_ -ge 1GB }{ "{0:#.#'G'}" -f ($size / 1GB); break }
				{ $_ -ge 1MB }{ "{0:#.#'M'}" -f ($size / 1MB); break }
				{ $_ -ge 1KB }{ "{0:#'K'}" -f ($size / 1KB); break }
				default { "{0}" -f ($size) + "B" }
			}
		}
		
		$wmiq = 'SELECT * FROM Win32_LogicalDisk WHERE Size != Null AND DriveType >= 2'
	}
	
	PROCESS
	{
		foreach ($computer in $ComputerName)
		{
			try
			{
				if ($computer -eq $env:COMPUTERNAME)
				{
					$disks = Get-WmiObject -Query $wmiq -ComputerName $computer -ErrorAction Stop
				}
				else
				{
					$disks = Get-WmiObject -Query $wmiq -ComputerName $computer -Credential $Credential -ErrorAction Stop
				}
				
				if ($Format)
				{
					# Create array for $disk objects and then populate
					$diskarray = @()
					$disks | ForEach-Object {
						$diskarray += $_
					}
					$diskarray | Select-Object @{ n = 'Name'; e = { $_.SystemName } },
			   @{ n = 'Vol'; e = { $_.DeviceID } },
			   @{ n = 'Size'; e = { Format-HumanReadable $_.Size } },
			   @{ n = 'Used'; e = { Format-HumanReadable(($_.Size) - ($_.FreeSpace)) } },
			   @{ n = 'Avail'; e = { Format-HumanReadable $_.FreeSpace } },
			   @{ n = 'Use%'; e = { [int](((($_.Size) - ($_.FreeSpace))/($_.Size) * 100)) } },
			   @{ n = 'FS'; e = { $_.FileSystem } },
			   @{ n = 'Type'; e = { $_.Description } }
				}
				else
				{
					foreach ($disk in $disks)
					{
						$diskprops = @{
							'Volume' = $disk.DeviceID;
							'Size' = $disk.Size;
							'Used' = ($disk.Size - $disk.FreeSpace);
							'Available' = $disk.FreeSpace;
							'FileSystem' = $disk.FileSystem;
							'Type' = $disk.Description
							'Computer' = $disk.SystemName;
						}
						
						# Create custom PS object and apply type
						$diskobj = New-Object -TypeName PSObject -Property $diskprops
						$diskobj.PSObject.TypeNames.Insert(0, 'BinaryNature.DiskFree')
						Write-Output $diskobj
					}
				}
			}
			catch
			{
				# Check for common DCOM errors and display "friendly" output
				switch ($_)
				{
					{ $_.Exception.ErrorCode -eq 0x800706ba } `
					{
						$err = 'Unavailable (Host Offline or Firewall)';
						break;
					}
					{ $_.CategoryInfo.Reason -eq 'UnauthorizedAccessException' } `
					{
						$err = 'Access denied (Check User Permissions)';
						break;
					}
					default { $err = $_.Exception.Message }
				}
				Write-Warning "$computer - $err"
			}
		}
	}
	
	END { }
}

function Get-PendingReboot {
	Param(
		[String[]]$ComputerName = $env:COMPUTERNAME
	)
	Import-Module PSRemoteRegistry
	foreach ($Computer in $ComputerName) {
		#Check Reboot Pending :
		$Pending = $false
		if (Get-RegKey -ComputerName $Computer -Key "Software\Microsoft\Windows\CurrentVersion\Component Based Servicing" -Name RebootPending)
		{
			$Pending = $true
			$AutoUpdate = $false
			if(Get-RegKey -ComputerName $Computer -Key "SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" -Name RebootRequired)
			{
				$AutoUpdate = $true
			}
		}

		if ($AutoUpdate -eq $true)
		{
			Write-Host "($Computer) : There is a WindowsUpdate pending reboot" -ForegroundColor magenta
		}
		elseif ($Pending -eq $true)
		{
			Write-Host "($Computer) : There is a pending reboot" -ForegroundColor red
		}
		else
		{
			Write-Host "($Computer) : There is NO pending reboot" -ForegroundColor green
		}
	}
}

function UpTime {
	Param(
		[parameter(ValueFromPipeline=$True)]
		[String[]]$ComputerName = $env:COMPUTERNAME,
		[switch]$Simple,
		[System.Management.Automation.PSCredential]$Credential
	)
	$Upobj = @()
	foreach ($Computer in $Computername) {
		$param = @{
		'ComputerName' = $Computer
		'ErrorVariable' = 'WmiRequestError'
		}
		if ($Credential -and ($Computer -notin @($env:COMPUTERNAME,'.'))){$param.Credential = $Credential}

		try {
			$OperatingSystem = Get-WmiObject -Class Win32_OperatingSystem @param
		} Catch {
			$WmiRequestError
			break
		}

		if($OperatingSystem -and !$WmiRequestError) {
			$DateBoot = [System.Management.ManagementDateTimeconverter]::ToDateTime($OperatingSystem.LastBootUpTime)
			$sysuptime = (Get-Date) - $DateBoot
			if ($Simple) {
				"($Computer) Uptime : " +
					$sysuptime.days + " days " +
					$sysuptime.hours + " hours " +
					$sysuptime.minutes + " min " +
					$sysuptime.seconds + " sec"
			} else {
				[pscustomobject][ordered]@{
					'Server' = $Computer;
					'DateBoot' = $DateBoot;
					'Days' = $sysuptime.days;
					'Hours' = $sysuptime.hours;
					'Minutes' = $sysuptime.minutes;
					'Seconds' = $sysuptime.seconds
				}
			}
		}
		else {
			if ($Simple) {
				"($Computer) Uptime : " + " N/A"
			} else {
				[pscustomobject][ordered]@{
					'Server' = $Computer;
					'DateBoot' = "N/A";
					'Days' = "N/A";
					'Hours' = "N/A";
					'Minutes' = "N/A";
					'Seconds' = "N/A";
				}
			}
		}
	}
}


Function clx($SaveRows) {
	# Like Clear-Host (cls) but keeps history (scroll)
    If ($SaveRows) {
        [System.Console]::SetWindowPosition(0,[System.Console]::CursorTop-($SaveRows+1))
    } Else {
        [System.Console]::SetWindowPosition(0,[System.Console]::CursorTop)
   }
}

function p {
    param($computername)
    # -------------------------------------------
	# Function Name: p
	# Test if a computer is online (quick ping replacement)
	# -------------------------------------------
	test-connection $computername -count 1 -quiet
	}

function Reload-Profile {
    @(
        $Profile.AllUsersAllHosts,
        $Profile.AllUsersCurrentHost,
        $Profile.CurrentUserAllHosts,
        $Profile.CurrentUserCurrentHost
    ) | ForEach-Object {
        if(Test-Path $_){
            Write-Verbose "Running $_"
            . $_
        }
    }
}

function New-Console {
	
	$PSLnkPath = "${env:APPDATA}\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Windows PowerShell.lnk"
	$pi = New-Object "System.Diagnostics.ProcessStartInfo"
	$pi.FileName = $PSLnkPath
	$pi.UseShellExecute = $true

	# See "powershell -help" for info on -Command
	$pi.Arguments = "-NoExit -Command Set-Location $PWD"

	[System.Diagnostics.Process]::Start($pi)
}

function ll {
    param (
		$dir = ".", 
		$all = $false) 

    $origFg = $host.ui.rawui.foregroundColor 
    if ( $all ) { $toList = Get-ChildItem -force $dir }
    else { $toList = Get-ChildItem $dir }

    foreach ($Item in $toList)  
    { 
        Switch ($Item.Extension)  
        { 
            ".Exe" {$host.ui.rawui.foregroundColor = "Yellow"} 
            ".cmd" {$host.ui.rawui.foregroundColor = "Red"} 
            ".msh" {$host.ui.rawui.foregroundColor = "Red"} 
            ".vbs" {$host.ui.rawui.foregroundColor = "Red"} 
			".ps1" {$host.ui.rawui.foregroundColor = "magenta"}
			".psm1" {$host.ui.rawui.foregroundColor = "darkgreen"} 
            Default {$host.ui.rawui.foregroundColor = $origFg} 
        } 
        if ($item.Mode.StartsWith("d")) {$host.ui.rawui.foregroundColor = "Green"}
        $item 
    }  
    $host.ui.rawui.foregroundColor = $origFg 
}

function la { 
	Get-ChildItem -force 
}

function edit($x) {
	$prog86 = ${env:ProgramFiles(x86)}
	$nppprog86 = Join-Path $prog86 "Notepad++\Notepad++.exe"
	$npp = "$psdir\bin\npp\notepad++.exe"
	if (Test-Path $nppprog86) {
		. $nppprog86 $x
	}
	elseif (Test-Path $npp) {
		. $npp $x
	}
	else {
		. notepad $x
	}
}

function New-RandomPassword {
	param([parameter(mandatory=$false)][alias("p")][int]$intPasswordLength = 8) 

	#MAIN
	if ($intPasswordLength -lt 4) {return "password cannot be <4 chars"}   # -lt inférieur à

	$strNumbers = "1234567890"
	$strCapitalLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	$strLowerLetters = "abcdefghijklmnopqrstuvwxyz"
	$strSymbols = "@-?!#"
	$rand = new-object random

	for ($a=1; $a -le $intPasswordLength; $a++)  #inférieur -le inférieur ou égal à
	{
		if ($a -gt 4) { #supérieur à
			$b = $rand.next(0,4) + $a
			$b = $b % 4 + 1
		} else {
			$b = $a 
		}
		switch ($b)
		{
			"1" {$b = "$strNumbers"}
			"2" {$b = "$strCapitalLetters"}
			"3" {$b = "$strLowerLetters"}
			"4" {$b = "$strSymbols"}
		}
		$charset = $($b)
		$number = $rand.next(0,$charset.Length)
		$RandomPassword += $charset[$number]
	}
	return $RandomPassword
}

# use the OS system shell process to execute, useful for URL handlers and other registered system file types
Function Start-SystemProcess {
	[System.Diagnostics.Process]::Start("" + $args + $input)
}

function Set-GoogleTools {
	# common types of Google searches
	Function Google-Search {
		Start-SystemProcess ("http://www.google.com/search?hl=en&q=" + $args + $input)
	}

	Function Google-Image  {
		Start-SystemProcess ("http://images.google.com/images?sa=N&tab=wi&q=" + $args + $input)
	}

	Function Google-Video  {
		Start-SystemProcess ("http://video.google.com/videosearch?q=" + $args + $input)
	}

	Function Google-News   {
		Start-SystemProcess ("http://news.google.com/news?ned=us&hl=en&ned=us&q=" + $args + $input)
	}

	# common things or domains to search Google for
	Function Google-PowerShell {
		Google-Search ("PowerShell " + $args + $input)
	}

	Function Google-MSDN {
		Google-Search ("site:msdn.microsoft.com " + $args + $input)
	}
	
	# shortcuts for googling
	if (!(Get-Alias google -ErrorAction 0)) {Set-Alias -Name google -Value Google-Search}
	if (!(Get-Alias ggit -ErrorAction 0)) {Set-Alias -Name ggit -Value Google-Search}     # go google it
	if (!(Get-Alias gimg -ErrorAction 0)) {Set-Alias -Name gimg -Value Google-Image}
	if (!(Get-Alias gnews -ErrorAction 0)) {Set-Alias -Name gnews -Value Google-News}
	if (!(Get-Alias gvid -ErrorAction 0)) {Set-Alias -Name gvid -Value Google-Video}
	if (!(Get-Alias gpsh -ErrorAction 0)) {Set-Alias -Name gpsh -Value Google-PowerShell}
	if (!(Get-Alias gmsdn -ErrorAction 0)) {Set-Alias -Name gmsdn -Value Google-MSDN}
}

<#
MARCHE PAS !!!! ya un script qui casse l'alias ls !!
function Enable-AllLIBScripts {
	get-childitem "${psdir}\lib\Scripts\*.ps1" -Exclude SYS_INFO.ps1| sort | %{. $_}
}
#>