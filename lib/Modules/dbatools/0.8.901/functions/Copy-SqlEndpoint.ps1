﻿Function Copy-SqlEndpoint
{
<#
.SYNOPSIS 
Copy-SqlEndpoint migrates server endpoints from one SQL Server to another. 

.DESCRIPTION
By default, all endpoints are copied. The -Endpoints parameter is autopopulated for command-line completion and can be used to copy only specific endpoints.

If the endpoint already exists on the destination, it will be skipped unless -Force is used. 

.PARAMETER Source
Source SQL Server.You must have sysadmin access and server version must be SQL Server version 2000 or greater.

.PARAMETER Destination
Destination Sql Server. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

.PARAMETER SourceSqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter. 

Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials. 	
To connect as a different Windows user, run PowerShell as that user.

.PARAMETER DestinationSqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$dcred = Get-Credential, then pass this $dcred to the -DestinationSqlCredential parameter. 

Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials. 	
To connect as a different Windows user, run PowerShell as that user.

.PARAMETER WhatIf 
Shows what would happen if the command were to run. No actions are actually performed. 

.PARAMETER Confirm 
Prompts you for confirmation before executing any changing operations within the command. 

.PARAMETER Force
Drops and recreates the endpoint if it exists

.NOTES
Tags: Migration
Author: Chrissy LeMaire (@cl), netnerds.net
Requires: sysadmin access on SQL Servers

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK
https://dbatools.io/Copy-SqlEndpoint

.EXAMPLE   
Copy-SqlEndpoint -Source sqlserver2014a -Destination sqlcluster

Copies all server endpoints from sqlserver2014a to sqlcluster, using Windows credentials. If endpoints with the same name exist on sqlcluster, they will be skipped.

.EXAMPLE   
Copy-SqlEndpoint -Source sqlserver2014a -Destination sqlcluster -Endpoint tg_noDbDrop -SourceSqlCredential $cred -Force

Copies a single endpoint, the tg_noDbDrop endpoint from sqlserver2014a to sqlcluster, using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If an endpoint with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.

.EXAMPLE   
Copy-SqlEndpoint -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

Shows what would happen if the command were executed using force.
#>
	[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
	param (
		[parameter(Mandatory = $true)]
		[object]$Source,
		[parameter(Mandatory = $true)]
		[object]$Destination,
		[System.Management.Automation.PSCredential]$SourceSqlCredential,
		[System.Management.Automation.PSCredential]$DestinationSqlCredential,
		[switch]$Force
	)
	DynamicParam { if ($source) { return (Get-ParamSqlServerEndpoints -SqlServer $Source -SqlCredential $SourceSqlCredential) } }
	
	BEGIN
	{
		$endpoints = $psboundparameters.Endpoints
		
		$sourceserver = Connect-SqlServer -SqlServer $Source -SqlCredential $SourceSqlCredential
		$destserver = Connect-SqlServer -SqlServer $Destination -SqlCredential $DestinationSqlCredential
		
		$source = $sourceserver.DomainInstanceName
		$destination = $destserver.DomainInstanceName
		
		if ($sourceserver.versionMajor -lt 9 -or $destserver.versionMajor -lt 9)
		{
			throw "Server Endpoints are only supported in SQL Server 2008 and above. Quitting."
		}
	}
	
	PROCESS
	{
		$serverendpoints = $sourceserver.Endpoints | Where-Object { $_.IsSystemObject -eq $false }
		$destendpoints = $destserver.Endpoints
		
		foreach ($endpoint in $serverendpoints)
		{
			$endpointname = $endpoint.name
			
			if ($endpoints.length -gt 0 -and $endpoints -notcontains $endpointname) { continue }
			
			if ($destendpoints.name -contains $endpointname)
			{
				if ($force -eq $false)
				{
					Write-Warning "Server endpoint $endpointname exists at destination. Use -Force to drop and migrate."
					continue
				}
				else
				{
					If ($Pscmdlet.ShouldProcess($destination, "Dropping server endpoint $endpointname and recreating"))
					{
						try
						{
							Write-Output "Dropping server endpoint $endpointname"
							$destserver.endpoints[$endpointname].Drop()
						}
						catch { 
							Write-Exception $_ 
							continue
						}
					}
				}
			}
			
			If ($Pscmdlet.ShouldProcess($destination, "Creating server endpoint $endpointname"))
			{
				try
				{
					Write-Output "Copying server endpoint $endpointname"
					$destserver.ConnectionContext.ExecuteNonQuery($endpoint.Script()) | Out-Null
				}
				catch
				{
					Write-Exception $_
				}
			}

		}
	}
	
	END
	{
		$sourceserver.ConnectionContext.Disconnect()
		$destserver.ConnectionContext.Disconnect()
		If ($Pscmdlet.ShouldProcess("console", "Showing finished message")) { Write-Output "Server endpoint migration finished" }
	}
}
