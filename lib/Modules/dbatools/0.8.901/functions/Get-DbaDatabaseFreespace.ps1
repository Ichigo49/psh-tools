﻿function Get-DbaDatabaseFreespace
{
<#
.SYNOPSIS
Returns database file space information for database files on a SQL instance.

.DESCRIPTION
This function returns database file space information for a SQL Instance or group of SQL 
Instances. Information is based on a query against sys.database_files and the FILEPROPERTY
function to query and return information. The function can accept a single instance or
multiple instances. By default, only user dbs will be shown, but using the IncludeSystemDBs
switch will include system databases

.NOTES 
Original Author: Michael Fal (@Mike_Fal), http://mikefal.net

File free space script borrowed and modified from Glenn Berry's DMV scripts (http://www.sqlskills.com/blogs/glenn/category/dmv-queries/)

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

.PARAMETER SqlServer
SQLServer name or SMO object representing the SQL Server to connect to. This can be a
collection and recieve pipeline input

.PARAMETER SqlCredential
PSCredential object to connect under. If not specified, currend Windows login will be used.

.PARAMETER IncludeSystemDBs
Switch parameter that when used will display system database information
	
.PARAMETER Databases
Specify one or more databases to process. 

.PARAMETER Exclude
Specify one or more databases to exclude.
	
.LINK
https://dbatools.io/Get-DbaDatabaseFreespace

.EXAMPLE
Get-DbaDatabaseFreespace -SqlServer localhost

Returns all user database files and free space information for the local host

.EXAMPLE
Get-DbaDatabaseFreespace -SqlServer localhost | Where-Object {$_.PercentUsed -gt 80}

Returns all user database files and free space information for the local host. Filters
the output object by any files that have a percent used of greater than 80%.

.EXAMPLE
@('localhost','localhost\namedinstance') | Get-DbaDatabaseFreespace

Returns all user database files and free space information for the localhost and
localhost\namedinstance SQL Server instances. Processes data via the pipeline.

.EXAMPLE
Get-DbaDatabaseFreespace -SqlServer localhost -Databases db1, db2

Returns database files and free space information for the db1 and db2 on localhost. 
#>
	[CmdletBinding()]
	param ([parameter(ValueFromPipeline, Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object[]]$SqlServer,
		[System.Management.Automation.PSCredential]$SqlCredential,
		[switch]$IncludeSystemDBs)
	
	DynamicParam { if ($SqlServer) { return Get-ParamSqlDatabases -SqlServer $SqlServer[0] -SqlCredential $SourceSqlCredential } }
	
	BEGIN
	{
		$sql = "SELECT 
				    @@SERVERNAME as SqlServer
				    ,DB_NAME() as DBName
				    ,f.name AS [FileName]
				    ,fg.name AS [Filegroup] 
				    ,f.physical_name AS [PhysicalName]
				    ,f.type_desc AS [FileType]
				    ,CAST(CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS FLOAT) as [UsedSpaceMB]
				    ,CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS FLOAT) AS [FreeSpaceMB]
				    ,CAST((f.size/128.0) AS FLOAT) AS [FileSizeMB]
				    ,CAST((FILEPROPERTY(f.name, 'SpaceUsed')/(f.size/1.0)) * 100 as FLOAT) as [PercentUsed]
					,CAST((f.growth/128.0) AS FLOAT) AS [GrowthMB]
					,CASE is_percent_growth WHEN 1 THEN 'pct' WHEN 0 THEN 'MB' ELSE 'Unknown' END AS [GrowthType]
					,CASE f.max_size WHEN -1 THEN 2147483648. ELSE CAST((f.max_size/128.0) AS FLOAT) END AS [MaxSizeMB]
					,CAST((f.size/128.0) AS FLOAT) - CAST(CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS FLOAT) AS [SpaceBeforeAutoGrow]
					,CASE f.max_size	WHEN (-1)
										THEN CAST(((2147483648.) - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int))/128.0 AS FLOAT)
										ELSE CAST((f.max_size - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int))/128.0 AS FLOAT)
										END AS [SpaceBeforeMax]
					,CASE f.growth	WHEN 0 THEN 0.00
									ELSE	CASE f.is_percent_growth	WHEN 0
													THEN	CASE f.max_size
															WHEN (-1)
															THEN CAST(((((2147483648.)-f.Size)/f.Growth)*f.Growth)/128.0 AS FLOAT)
															ELSE CAST((((f.max_size-f.Size)/f.Growth)*f.Growth)/128.0 AS FLOAT)
															END
													WHEN 1
													THEN	CASE f.max_size
															WHEN (-1)
															THEN CAST(CONVERT([int],f.Size*power((1)+CONVERT([float],f.Growth)/(100),CONVERT([int],log10(CONVERT([float],(2147483648.))/CONVERT([float],f.Size))/log10((1)+CONVERT([float],f.Growth)/(100)))))/128.0 AS FLOAT)
															ELSE CAST(CONVERT([int],f.Size*power((1)+CONVERT([float],f.Growth)/(100),CONVERT([int],log10(CONVERT([float],f.Max_Size)/CONVERT([float],f.Size))/log10((1)+CONVERT([float],f.Growth)/(100)))))/128.0 AS FLOAT)
															END
													ELSE (0)
													END
									END AS [PossibleAutoGrowthMB]
					, CASE f.growth	WHEN 0 THEN	CASE f.max_size
												WHEN (-1)
												THEN CAST(((2147483648.) - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int))/128.0 AS FLOAT)
												ELSE CAST((f.max_size - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int))/128.0 AS FLOAT)
												END
									ELSE CAST((f.max_size - f.size - (	CASE f.is_percent_growth
												WHEN 0
												THEN	CASE f.max_size
														WHEN (-1)
														THEN CONVERT(FLOAT,((((2147483648.)-f.Size)/f.Growth)*f.Growth))
														ELSE CONVERT(FLOAT,(((f.max_size-f.Size)/f.Growth)*f.Growth))
														END
												WHEN 1
												THEN	CASE f.max_size
														WHEN (-1)
														THEN CONVERT([int],f.Size*power((1)+CONVERT([float],f.Growth)/(100),CONVERT([int],log10(CONVERT([float],(2147483648.))/CONVERT([float],f.Size))/log10((1)+CONVERT([float],f.Growth)/(100)))))
														ELSE CONVERT([int],f.Size*power((1)+CONVERT([float],f.Growth)/(100),CONVERT([int],log10(CONVERT([float],f.Max_Size)/CONVERT([float],f.Size))/log10((1)+CONVERT([float],f.Growth)/(100)))))
														END
														ELSE (0)
														END ))/128.0 AS FLOAT)
									END AS [UnusableSpaceMB]
 
				FROM sys.database_files AS f WITH (NOLOCK) 
				LEFT OUTER JOIN sys.filegroups AS fg WITH (NOLOCK)
				ON f.data_space_id = fg.data_space_id"
		
		$databases = $psboundparameters.Databases
		$exclude = $psboundparameters.Exclude
	}
	
	PROCESS
	{
		foreach ($instance in $SqlServer)
		{
            try
            {
			    #For each SQL Server in collection, connect and get SMO object
			    Write-Verbose "Connecting to $instance"
			    $server = Connect-SqlServer $instance -SqlCredential $SqlCredential
            }
            catch
            {
					Write-Warning "Can't connect to $instance. Moving on."
					Continue
			}
			
			#If IncludeSystemDBs is true, include systemdbs
			#look at all databases, online/offline/accessible/inaccessible and tell user if a db can't be queried.
			try
			{
				if ($databases.length -gt 0)
				{
					$dbs = $server.Databases | Where-Object { $databases -contains $_.Name }
				}
				elseif ($IncludeSystemDBs)
				{
					$dbs = $server.Databases | Where-Object { $_.status -eq 'Normal' }
				}
				else
				{
					$dbs = $server.Databases | Where-Object { $_.status -eq 'Normal' -and $_.IsSystemObject -eq 0 }
				}
				
				if ($exclude.length -gt 0)
				{
					$dbs = $dbs | Where-Object { $exclude -notcontains $_.Name }
				}
			}
			catch
			{
				Write-Exception $_
				Write-Warning "Unable to gather databases for $instance"
				continue
			}
			
			foreach ($db in $dbs)
			{
				try
				{
					Write-Verbose "Querying $instance - $db"
                    If($db.status -ne 'Normal' -or $db.IsAccessible -eq $false)
                    {
                        Write-Warning "$db is not accessible."
						continue
                    }
					    #Execute query against individual database and add to output
					    foreach ($row in ($db.ExecuteWithResults($sql)).Tables[0])
						{
							If ($row.UsedSpaceMB -is [System.DBNull]) { $UsedMB = 0 } Else { $UsedMB = [Math]::Round($row.UsedSpaceMB) }
							If ($row.FreeSpaceMB -is [System.DBNull]) { $FreeMB = 0 } Else { $FreeMB = [Math]::Round($row.FreeSpaceMB) }
							If ($row.PercentUsed -is [System.DBNull]) { $PercentUsed = 0 } Else { $PercentUsed = [Math]::Round($row.PercentUsed) }
							If ($row.SpaceBeforeMax -is [System.DBNull]) { $SpaceUntilMax = 0 } Else { $SpaceUntilMax = [Math]::Round($row.SpaceBeforeMax) }
							If ($row.UnusableSpaceMB -is [System.DBNull]) { $UnusableSpace = 0 } Else { $UnusableSpace = [Math]::Round($row.UnusableSpaceMB) }

							[pscustomobject]@{
								Server = $row.SqlServer
								Database = $row.DBName
								FileName = $row.FileName
								FileGroup = $row.FileGroup
								PhysicalName = $row.PhysicalName
								FileType = $row.FileType
								UsedSpaceMB = $UsedMB
								FreeSpaceMB = $FreeMB
								FileSizeMB = $row.FileSizeMB
								PercentUsed = $PercentUsed
								AutoGrowth = $row.GrowthMB
								AutoGrowType = $row.GrowthType
								SpaceUntilMaxSizeMB = $SpaceUntilMax
								AutoGrowthPossibleMB = $row.PossibleAutoGrowthMB
								UnusableSpaceMB = $UnusableSpace
							}
						}
				}
				catch
				{
					Write-Exception $_
					Write-Warning "Unable to query $instance - $db"
					continue
				}
				
				foreach ($row in $result)
				{
					[pscustomobject]@{
						SqlServer = $row.SqlServer
						DatabaseName = $row.DBName
						FileName = $row.FileName
						FileGroup = $row.FileGroup
						PhysicalName = $row.PhysicalName
						UsedSpaceMB = $row.UsedSpaceMB
						FreeSpaceMB = $row.FreeSpaceMB
						FileSizeMB = $row.FileSizeMB
						PercentUsed = $row.PercentUSed
					}
				}
			}
		}
	}
}
