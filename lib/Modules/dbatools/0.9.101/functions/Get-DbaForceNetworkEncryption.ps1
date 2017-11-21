#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#

function Get-DbaForceNetworkEncryption {
<#
	.SYNOPSIS
		Gets Force Encryption settings for a SQL Server instance
	
	.DESCRIPTION
		Gets Force Encryption settings for a SQL Server instance. Note that this requires access to the Windows Server - not the SQL instance itself.
		
		This setting is found in Configuration Manager.
	
	.PARAMETER SqlInstance
		The target SQL Server - defaults to localhost.
	
	.PARAMETER Credential
		Allows you to login to the computer (not sql instance) using alternative Windows credentials
	
	.PARAMETER EnableException
		By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
		This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
		Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		
	.PARAMETER WhatIf
		Shows what would happen if the command were to run. No actions are actually performed
	
	.PARAMETER Confirm
		Prompts you for confirmation before executing any changing operations within the command
	
	.EXAMPLE
		Get-DbaForceNetworkEncryption
		
		Gets Force Encryption properties on the default (MSSQLSERVER) instance on localhost - requires (and checks for) RunAs admin.
	
	.EXAMPLE
		Get-DbaForceNetworkEncryption -SqlInstance sql01\SQL2008R2SP2
		
		Gets Force Network Encryption for the SQL2008R2SP2 on sql01. Uses Windows Credentials to both login and view the registry.
	
	.NOTES
		Tags: Certificate
		
		Website: https://dbatools.io
		Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
		License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
#>
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer", "ComputerName")]
		[DbaInstanceParameter[]]
		$SqlInstance = $env:COMPUTERNAME,
		
		[PSCredential]
		
		$Credential,
		
		[switch]
		[Alias('Silent')]$EnableException
	)
	process {
		
		foreach ($instance in $SqlInstance) {
			Write-Message -Level VeryVerbose -Message "Processing $instance" -Target $instance
			$null = Test-ElevationRequirement -ComputerName $instance -Continue
			
			Write-Message -Level Verbose -Message "Resolving hostname"
			$resolved = $null
			$resolved = Resolve-DbaNetworkName -ComputerName $instance
			
			if ($null -eq $resolved) {
				Stop-Function -Message "Can't resolve $instance" -Target $instance -Continue -Category InvalidArgument
			}
			
			Write-Message -Level Verbose -Message "Connecting to SQL WMI on $($instance.ComputerName)"
			try {
				$sqlwmi = Invoke-ManagedComputerCommand -ComputerName $resolved.FQDN -ScriptBlock { $wmi.Services } -Credential $Credential -ErrorAction Stop | Where-Object DisplayName -eq "SQL Server ($($instance.InstanceName))"
			}
			catch {
				Stop-Function -Message "Failed to access $instance" -Target $instance -Continue -ErrorRecord $_
			}
			
			$regroot = ($sqlwmi.AdvancedProperties | Where-Object Name -eq REGROOT).Value
			$vsname = ($sqlwmi.AdvancedProperties | Where-Object Name -eq VSNAME).Value
			$instancename = $sqlwmi.DisplayName.Replace('SQL Server (', '').Replace(')', '') # Don't clown, I don't know regex :(
			$serviceaccount = $sqlwmi.ServiceAccount
			
			if ([System.String]::IsNullOrEmpty($regroot)) {
				$regroot = $sqlwmi.AdvancedProperties | Where-Object { $_ -match 'REGROOT' }
				$vsname = $sqlwmi.AdvancedProperties | Where-Object { $_ -match 'VSNAME' }
				
				if (![System.String]::IsNullOrEmpty($regroot)) {
					$regroot = ($regroot -Split 'Value\=')[1]
					$vsname = ($vsname -Split 'Value\=')[1]
				}
				else {
					Stop-Function -Message "Can't find instance $vsname on $instance" -Continue -Category ObjectNotFound -Target $instance
				}
			}
			
			if ([System.String]::IsNullOrEmpty($vsname)) { $vsname = $instance }
			
			Write-Message -Level Verbose -Message "Regroot: $regroot" -Target $instance
			Write-Message -Level Verbose -Message "ServiceAcct: $serviceaccount" -Target $instance
			Write-Message -Level Verbose -Message "InstanceName: $instancename" -Target $instance
			Write-Message -Level Verbose -Message "VSNAME: $vsname" -Target $instance
			
			$scriptblock = {
				$regpath = "Registry::HKEY_LOCAL_MACHINE\$($args[0])\MSSQLServer\SuperSocketNetLib"
				$cert = (Get-ItemProperty -Path $regpath -Name Certificate).Certificate
				$forceencryption = (Get-ItemProperty -Path $regpath -Name ForceEncryption).ForceEncryption
				
				# [pscustomobject] doesn't always work, unsure why. so return hashtable then turn it into  pscustomobject on client
				@{
					ComputerName		  = $env:COMPUTERNAME
					InstanceName		  = $args[2]
					SqlInstance		      = $args[1]
					ForceEncryption	      = ($forceencryption -eq $true)
					CertificateThumbprint = $cert
				}
			}
			
			if ($PScmdlet.ShouldProcess("local", "Connecting to $instance")) {
				try {
					$results = Invoke-Command2 -ComputerName $resolved.fqdn -Credential $Credential -ArgumentList $regroot, $vsname, $instancename -ScriptBlock $scriptblock -ErrorAction Stop -Raw
					foreach ($result in $results) {
						[pscustomobject]$result	
					}
				}
				catch {
					Stop-Function -Message "Failed to connect to $($resolved.fqdn) using PowerShell remoting!" -ErrorRecord $_ -Target $instance -Continue
				}
			}
		}
	}
}