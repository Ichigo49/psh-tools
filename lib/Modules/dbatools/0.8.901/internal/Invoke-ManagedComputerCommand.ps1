﻿Function Invoke-ManagedComputerCommand
{
<#
.SYNOPSIS
Internal command
	
#>	
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ComputerName")]
		[object]$Server,
		[System.Management.Automation.PSCredential]$Credential,
		[Parameter(Mandatory = $true)]
		[scriptblock]$ScriptBlock,
		[string[]]$ArgumentList
	)
	
	if ($Server.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server])
	{
		$server = $server.ComputerNamePhysicalNetBIOS
	}
	
	# Remove instance name if it as passed
	$server = ($Server.Split("\"))[0]
	
	if ($Server -eq $env:COMPUTERNAME -or $Server -eq 'localhost' -or $Server -eq '.')
	{
		$Server = 'localhost'
		if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
		{
			throw "This command must be run with elevated privileges for the local host."
		}
	}
	
	$ipaddr = (Test-Connection $server -Count 1 -ErrorAction Stop).Ipv4Address
	$ArgumentList += $ipaddr
		
	[scriptblock]$setupScriptBlock = {
		$ipaddr = $args[$args.GetUpperBound(0)]
		
		# Just in case we go remote, ensure the assembly is loaded
		[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement')
		
		$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer $ipaddr
		$null = $wmi.Initialize()
	}
	
	$prescriptblock = $setupScriptBlock.ToString()
	$postscriptblock = $ScriptBlock.ToString()
	
	$scriptblock = [ScriptBlock]::Create("$prescriptblock  $postscriptblock")
		
	try
	{
		if ($credential.username -ne $null)
		{
			$result = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Credential $Credential
		}
		else
		{
			$result = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
		}
		
		Write-Verbose "Local connection for $server succeeded"
	}
	catch
	{
		try
		{
			Write-Verbose "Local connection attempt to $Server failed. Connecting remotely."
			
			# For surely resolve stuff
			$hostname = [System.Net.Dns]::gethostentry($ipaddr)
			$hostname = $hostname.HostName
			
			if ($credential.username -ne $null)
			{
				$result = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Credential $Credential -ComputerName $hostname
			}
			else
			{
				$result = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -ComputerName $hostname
			}
		}
		catch
		{
			throw $_
		}
	}
	
	$result | Select-Object * -ExcludeProperty PSComputerName, RunSpaceID, PSShowComputerName
}
