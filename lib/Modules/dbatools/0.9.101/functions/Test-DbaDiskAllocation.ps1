function Test-DbaDiskAllocation {
	<#
		.SYNOPSIS
			Checks all disks on a computer to see if they are formatted with allocation units of 64KB. 
			
		.DESCRIPTION
			Checks all disks on a computer for disk allocation units that match best practice recommendations. If one server is checked, only $true or $false is returned. If multiple servers are checked, each server's name and an IsBestPractice field are returned.
			
			Specify -Detailed for details.
			
			References:
			https://technet.microsoft.com/en-us/library/dd758814(v=sql.100).aspx - "The performance question here is usually not one of correlation per the formula, but whether the cluster size has been explicitly defined at 64 KB, which is a best practice for SQL Server."
			
			http://tk.azurewebsites.net/2012/08/
			
		.PARAMETER ComputerName
			The server(s) to check disk configuration on.

		.PARAMETER NoSqlCheck
			If this switch is enabled, the disk(s) will not be checked for SQL Server data or log files.
			
		.PARAMETER SqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

			$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

			Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

			To connect as a different Windows user, run PowerShell as that user.		
		
		.PARAMETER Detailed
			If this switch is enabled, detailed output is produced.

		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

		.PARAMETER Confirm
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.NOTES
			Tags: CIM, Storage
			Requires: Windows sysadmin access on SQL Servers
				
			dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
			Copyright (C) 2016 Chrissy LeMaire
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Test-DbaDiskAllocation

		.EXAMPLE
			Test-DbaDiskAllocation -ComputerName sqlserver2014a

			Scans all disks on server sqlserver2014a for best practice allocation unit size.

		.EXAMPLE   
			Test-DbaDiskAllocation -ComputerName sqlserver2014 -Detailed
			
			Scans all disks on server sqlserver2014a for allocation unit size and returns detailed results for each.
			
		.EXAMPLE   
			Test-DbaDiskAllocation -ComputerName sqlserver2014a -NoSqlCheck

			Scans all disks not hosting SQL Server data or log files on server sqlserver2014a for best practice allocation unit size.
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	[OutputType("System.Collections.ArrayList", "System.Boolean")]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer", "SqlInstance")]
		[object[]]$ComputerName,
		[switch]$NoSqlCheck,
		[object]$SqlCredential,
		[switch]$Detailed,
		[switch][Alias('Silent')]$EnableException
	)
	
	begin {
		if ($Detailed) {
			Write-Message -Level Warning -Message "Detailed is deprecated and will be removed in dbatools 1.0."
		}
		
		$sessionoptions = New-CimSessionOption -Protocol DCOM
		
		function Get-AllDiskAllocation {
			$alldisks = @()
			$SqlInstances = @()
			
			try {
				Write-Message -Level Verbose -Message "Getting disk information from $computer."
				
				# $query = "Select Label, BlockSize, Name from Win32_Volume WHERE FileSystem='NTFS'"
				# $disks = Get-WmiObject -ComputerName $ipaddr -Query $query | Sort-Object -Property Name
				$disks = Get-CimInstance -CimSession $CIMsession -ClassName win32_volume -Filter "FileSystem='NTFS'" -ErrorAction Stop | Sort-Object -Property Name
			}
			catch {
				Stop-Function -Message "Can't connect to WMI on $computer."
				return
			}
			
			if ($NoSqlCheck -eq $false) {
				Write-Message -Level Verbose -Message "Checking for SQL Services"
				$sqlservices = Get-Service -ComputerName $ipaddr | Where-Object { $_.DisplayName -like 'SQL Server (*' }
				foreach ($service in $sqlservices) {
					$instance = $service.DisplayName.Replace('SQL Server (', '')
					$instance = $instance.TrimEnd(')')
					
					$instancename = $instance.Replace("MSSQLSERVER", "Default")
					Write-Message -Level Verbose -Message "Found instance $instancename."
					
					if ($instance -eq 'MSSQLSERVER') {
						$SqlInstances += $ipaddr
					}
					else {
						$SqlInstances += "$ipaddr\$instance"
					}
				}
				$sqlcount = $SqlInstances.Count
				
				Write-Message -Level Verbose -Message "$sqlcount instance(s) found."
			}
			
			foreach ($disk in $disks) {
				if (!$disk.name.StartsWith("\\")) {
					$diskname = $disk.Name
					
					if ($NoSqlCheck -eq $false) {
						$sqldisk = $false
						
						foreach ($SqlInstance in $SqlInstances) {
							Write-Message -Level Verbose -Message "Connecting to SQL instance ($SqlInstance)."
							try {
								$smoserver = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
								$sql = "Select count(*) as Count from sys.master_files where physical_name like '$diskname%'"
								$sqlcount = $smoserver.Databases['master'].ExecuteWithResults($sql).Tables[0].Count
								if ($sqlcount -gt 0) {
									$sqldisk = $true
									break
								}
							}
							catch {
								Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
								continue
							}
						}
					}
					
					if ($disk.BlockSize -eq 65536) {
						$IsBestPractice = $true
					}
					else {
						$IsBestPractice = $false
					}
					
					$windowsdrive = "$env:SystemDrive\"
					
					if ($diskname -eq $windowsdrive) {
						$IsBestPractice = $false
					}
					
					if ($NoSqlCheck -eq $false) {
						$alldisks += [PSCustomObject]@{
							Server         = $computer
							Name           = $diskname
							Label          = $disk.Label
							BlockSize      = $disk.BlockSize
							IsSqlDisk      = $sqldisk
							IsBestPractice = $IsBestPractice
						}
					}
					else {
						$alldisks += [PSCustomObject]@{
							Server         = $computer
							Name           = $diskname
							Label          = $disk.Label
							BlockSize      = $disk.BlockSize
							IsBestPractice = $IsBestPractice
						}
					}
				}
			}
			return $alldisks
		}
	}
	
	process {
		foreach ($computer in $ComputerName) {
			
			$computer = Resolve-DbaNetworkName -ComputerName $computer -Credential $credential
			$ipaddr = $computer.IpAddress
			$Computer = $computer.ComputerName
			
			if (!$Computer) {
				Stop-Function -Message "Couldn't resolve hostname. Skipping." -Continue
			}
			
			Write-Message -Level Verbose -Message "Creating CimSession on $computer over WSMan."
			
			if (!$Credential) {
				$cimsession = New-CimSession -ComputerName $Computer -ErrorAction SilentlyContinue
			}
			else {
				$cimsession = New-CimSession -ComputerName $Computer -ErrorAction SilentlyContinue -Credential $Credential
			}
			
			if ($null -eq $cimsession.id) {
				Write-Message -Level Verbose -Message "Creating CimSession on $computer over WSMan failed. Creating CimSession on $computer over DCOM."
				
				if (!$Credential) {
					$cimsession = New-CimSession -ComputerName $Computer -SessionOption $sessionoption -ErrorAction SilentlyContinue -Credential $Credential
				}
				else {
					$cimsession = New-CimSession -ComputerName $Computer -SessionOption $sessionoption -ErrorAction SilentlyContinue
				}
			}
			
			if ($null -eq $cimsession.id) {
				Stop-Function -Message "Can't create CimSession on $computer" -Target $Computer
			}
			
			Write-Message -Level Verbose -Message "Getting Power Plan information from $Computer"
			
			$data = Get-AllDiskAllocation $computer
						
			if ($data.Count -gt 1) {
				$data.GetEnumerator()
			}
			else {
				$data
			}
		}
	}
}