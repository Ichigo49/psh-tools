﻿Function Get-DbaDatabaseState
{
<#
.SYNOPSIS
Gets various options for databases, hereby called "states"

.DESCRIPTION
Gets some common "states" on databases:
 - "RW" options : READ_ONLY or READ_WRITE
 - "Status" options : ONLINE, OFFLINE, EMERGENCY
 - "Access" options : SINGLE_USER, RESTRICTED_USER, MULTI_USER

Returns an object with SqlInstance, Database, RW, Status, Access

.PARAMETER SqlInstance
The SQL Server that you're connecting to

.PARAMETER Credential
Credential object used to connect to the SQL Server as a different user

.PARAMETER Database
Gets options only on these databases

.PARAMETER Exclude
Gets options for all but these specific databases

.NOTES
Author: niphlod

dbatools PowerShell module (https://dbatools.io)
Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

.LINK
https://dbatools.io/Get-DbaDatabaseState

.EXAMPLE
Get-DbaDatabaseState -SqlInstance sqlserver2014a

Gets options for all databases of the sqlserver2014a instance

.EXAMPLE
Get-DbaDatabaseState -SqlInstance sqlserver2014a -Database HR, Accounting

Gets options for both HR and Accounting database of the sqlserver2014a instance

.EXAMPLE
Get-DbaDatabaseState -SqlInstance sqlserver2014a -Exclude HR

Gets options for all databases of the sqlserver2014a instance except HR

.EXAMPLE
'sqlserver2014a', 'sqlserver2014b' | Get-DbaDatabaseState

Gets options for all databases of sqlserver2014a and sqlserver2014b instances

#>
	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[object[]]$SqlInstance,
		[PSCredential]
		[System.Management.Automation.CredentialAttribute()]$Credential
	)

	DynamicParam
	{
		if ($SqlInstance)
		{
			Get-ParamSqlDatabases -SqlServer $SqlInstance[0] -SqlCredential $Credential -NoSystem
		}
	}

	BEGIN
	{
		$databases = $psboundparameters.Databases
		$exclude = $psboundparameters.Exclude


		$UserAccessHash = @{
			'Single' = 'SINGLE_USER'
			'Restricted' = 'RESTRICTED_USER'
			'Multiple' = 'MULTI_USER'
		}
		$ReadOnlyHash = @{
			$true = 'READ_ONLY'
			$false = 'READ_WRITE'
		}
		$StatusHash = @{
			'Offline' = 'OFFLINE'
			'Normal' = 'ONLINE'
			'EmergencyMode' = 'EMERGENCY'
		}

		function Get-DbState($db)
		{
			$base = [PSCustomObject]@{
				'Access' = ''
				'Status' = ''
				'RW' = ''
			}
			$base.RW = $ReadOnlyHash[$db.ReadOnly]
			$base.Access = $UserAccessHash[$db.UserAccess.toString()]
			foreach($status in $StatusHash.Keys)
			{
				if($db.Status -match $status)
				{
					$base.Status = $StatusHash[$status]
					break
				}
			}
			return $base
		}

	}
	PROCESS
	{
		foreach ($instance in $SqlInstance)
		{
			Write-Verbose "Connecting to $instance"
			try
			{
				$server = Connect-SqlServer -SqlServer $instance -SqlCredential $Credential
			}
			catch
			{
				Write-Warning "Can't connect to $instance"
				Continue
			}
			$all_dbs = $server.Databases
			$dbs = $all_dbs | Where-Object { @('master', 'model', 'msdb', 'tempdb', 'distribution') -notcontains $_.Name }

			if ($databases.count -gt 0)
			{
				$dbs = $dbs | Where-Object { $databases -contains $_.Name }
			}
			if ($exclude.count -gt 0)
			{
				$dbs = $dbs | Where-Object { $exclude -notcontains $_.Name }
			}
			foreach($db in $dbs)
			{
				$db_status = Get-DbState $db

				[PSCustomObject]@{
					SqlInstance   = $server.Name
					InstanceName  = $server.ServiceName
					ComputerName  = $server.NetName
					DatabaseName  = $db.Name
					RW            = $db_status.RW
					Status        = $db_status.Status
					Access        = $db_status.Access
					Database      = $db
				} | Select-DefaultView -ExcludeProperty Database
			}
		}
	}
}
