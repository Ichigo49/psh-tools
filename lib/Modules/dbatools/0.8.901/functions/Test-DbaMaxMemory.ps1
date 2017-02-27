﻿Function Test-DbaMaxMemory
{
<# 
.SYNOPSIS 
Calculates the recommended value for SQL Server 'Max Server Memory' configuration setting. Works on SQL Server 2000-2014.

.DESCRIPTION 
Inspired by Jonathan Kehayias's post about SQL Server Max memory (http://bit.ly/sqlmemcalc), this script displays a SQL Server's: 
total memory, currently configured SQL max memory, and the calculated recommendation.

Jonathan notes that the formula used provides a *general recommendation* that doesn't account for everything that may be going on in your specific environment. 

.PARAMETER SqlServer
Allows you to specify a comma separated list of servers to query.

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$cred = Get-Credential, then pass $cred variable to this parameter. 

Windows Authentication will be used when SqlCredential is not specified. To connect as a different Windows user, run PowerShell as that user.	

.NOTES
Tags: Memory
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.LINK 
https://dbatools.io/Test-DbaMaxMemory

.EXAMPLE   
Test-DbaMaxMemory -SqlServer sqlcluster,sqlserver2012

Calculate the 'Max Server Memory' settings for all servers within the SQL Server Central Management Server "sqlcluster"

.EXAMPLE 
Test-DbaMaxMemory -SqlServer sqlcluster | Where-Object { $_.SqlMaxMB -gt $_.TotalMB } | Set-DbaMaxMemory 

Find all servers in CMS that have Max SQL memory set to higher than the total memory of the server (think 2147483647) and set it to recommended value. 

#>

	[CmdletBinding()]
	Param (
		[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
		[Alias("ServerInstance", "SqlInstance", "SqlServers")]
		[object]$SqlServer,
		[System.Management.Automation.PSCredential]$SqlCredential
	)
	
	PROCESS
	{
		foreach ($servername in $sqlserver)
		{
			Write-Verbose "Counting the running SQL Server instances on $servername"

			try
			{
				# Get number of instances running
				$ipaddr = Resolve-SqlIpAddress -SqlServer $servername
				$sqls = Get-Service -ComputerName $ipaddr | Where-Object { $_.DisplayName -like 'SQL Server (*' -and $_.Status -eq 'Running' }
				$sqlcount = $sqls.count
			}
			catch
			{
				Write-Warning "Couldn't get accurate SQL Server instance count on $servername. Defaulting to 1."
				$sqlcount = 1
			}
			

            $server = Get-DbaMaxMemory -SqlServer $servername -SqlCredential $SqlCredential
			
			if($null -eq $server)
            {
                continue;
            }

		
			$reserve = 1

            $maxmemory = $server.SqlMaxMB
            $totalmemory = $server.TotalMB

			if ($totalmemory -ge 4096)
			{
				$currentCount = $totalmemory
				while ($currentCount/4096 -gt 0)
				{
					if ($currentCount -gt 16384)
					{
						$reserve += 1
						$currentCount += -8192
					}
					else
					{
						$reserve += 1
						$currentCount += -4096
					}
				}
				$recommendedMax = [int]($totalmemory - ($reserve * 1024))
			}
			else
			{
				$recommendedMax = $totalmemory * .5
			}
			
			$recommendedMax = $recommendedMax/$sqlcount
			
			[pscustomobject]@{
				Server = $server.Server
				InstanceCount = $sqlcount
				TotalMB = $totalmemory
				SqlMaxMB = $maxmemory
				RecommendedMB = $recommendedMax
			}
		}
	}
}


