﻿function Restore-DbaDatabase
{
<#
.SYNOPSIS 
Restores a SQL Server Database from a set of backupfiles

.DESCRIPTION
Upon bein passed a list of potential backups files this command will scan the files, select those that contain SQL Server
backup sets. It will then filter those files down to a set that can perform the requested restore, checking that we have a 
full restore chain to the point in time requested by the caller.

Various means can be used to pass in a list of files to be considered. The default is to non recursively scan the folder
passed in. 

.PARAMETER SqlServer
The SQL Server instance. 

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. 

.PARAMETER Path
Path to SQL Server backup files. 

Paths passed in as strings will be scanned using the desired method, default is a non recursive folder scan
Accepts multiple paths seperated by ','

Or it can consist of FileInfo objects, such as the output of Get-ChildItem or Get-Item. This allows you to work with 
your own filestructures as needed

.PARAMETER DestinationDataDirectory
Path to restore the SQL Server backups to on the target instance.
If only this parameter is specified, then all database files (data and log) will be restored to this location

.PARAMETER DestinationLogDirectory
Path to restore the database log files to.
This parameter can only be specified alongside DestinationDataDirectory.

.PARAMETER DestinationFilePrefix 
This value will be prefixed to ALL restored files (log and data). This is just a simple string prefix. If you 
want to perform more complex rename operations then please use the FileMapping parameter

This will apply to all file move options, except for FileMapping

.PARAMETER UseDestinationDefaultDirectories
Switch that tells the restore to use the default Data and Log locations on the target server

.PARAMETER RestoreTime
Specify a DateTime object to which you want the database restored to. Default is to the latest point available 

.PARAMETER MaintenanceSolutionBackup
Switch to indicate the backup files are in a folder structure as created by Ola Hallengreen's maintenance scripts.
This swith enables a faster check for suitable backups. Other options require all files to be read first to ensure
we have an anchoring full backup. Because we can rely on specific locations for backups performed with OlaHallengren's 
backup solution, we can rely on file locations.

.PARAMETER DatabaseName
Name to restore the database under

.PARAMETER NoRecovery
Indicates if the database should be recovered after last restore. Default is to recover

.PARAMETER WithReplace
Switch indicated is the restore is allowed to replace an existing database.

.PARAMETER OutputScriptOnly
Switch indicates that ONLY T-SQL scripts should be generated, no restore takes place

.PARAMETER VerifyOnly
Switch indicate that restore should be verified

.PARAMETER XpDirTree
Switch that indicated file scanning should be performed by the SQL Server instance using xp_dirtree
This will scan recursively from the passed in path
You must have sysadmin role membership on the instance for this to work.

.PARAMETER FileMapping
A hashtable that can be used to move specific files to a location.
$FileMapping = @{'DataFile1'='c:\restoredfiles\Datafile1.mdf';'DataFile3'='d:\DataFile3.mdf'}
And files not specified in the mapping will be restore to their original location
This Parameter is exclusive with DestinationDataDirectory

.PARAMETER IgnoreLogBackup
This switch tells the function to ignore transaction log backups. The process will restore to the latest full or differential backup point only

.PARAMETER ReuseSourceFolderStructure
By default, databases will be migrated to the destination Sql Server's default data and log directories. You can override this by specifying -ReuseSourceFolderStructure. 
The same structure on the SOURCE will be kept exactly, so consider this if you're migrating between different versions and use part of Microsoft's default Sql structure (MSSql12.INSTANCE, etc)

*Note, to reuse destination folder structure, specify -WithReplace
	
.PARAMETER Confirm
Prompts to confirm certain actions
	
.PARAMETER WhatIf
Shows what would happen if the command would execute, but does not actually perform the command

.NOTES
Tags: DisasterRecovery, Backup, Restore
Original Author: Stuart Moore (@napalmgram), stuart-moore.com

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.

.EXAMPLE
Restore-DbaDatabase -SqlServer server1\instance1 -Path \\server2\backups 

Scans all the backup files in \\server2\backups, filters them and restores the database to server1\instance1

.EXAMPLE
Restore-DbaDatabase -SqlServer server1\instance1 -Path \\server2\backups -MaintenanceSolutionBackup -DestinationDataDirectory c:\restores

Scans all the backup files in \\server2\backups$ stored in an Ola Hallengren style folder structure,
 filters them and restores the database to the c:\restores folder on server1\instance1 

.EXAMPLE
Get-ChildItem c:\SQLbackups1\, \\server\sqlbackups2 | Restore-DbaDatabase -SqlServer server1\instance1 

Takes the provided files from multiple directories and restores them on  server1\instance1 

.EXAMPLE
$RestoreTime = Get-Date('11:19 23/12/2016')
Restore-DbaDatabase -SqlServer server1\instance1 -Path \\server2\backups -MaintenanceSolutionBackup -DestinationDataDirectory c:\restores -RestoreTime $RestoreTime

Scans all the backup files in \\server2\backups stored in an Ola Hallengren style folder structure,
 filters them and restores the database to the c:\restores folder on server1\instance1 up to 11:19 23/12/2016

.EXAMPLE
Restore-DbaDatabase -SqlServer server1\instance1 -Path \\server2\backups -DestinationDataDirectory c:\restores -OutputScriptOnly | Select-Object -ExpandPropert Tsql | Out-File -Filepath c:\scripts\restore.sql

Scans all the backup files in \\server2\backups stored in an Ola Hallengren style folder structure,
 filters them and generate the T-SQL Scripts to restore the database to the latest point in time, 
 and then stores the output in a file for later retrieval

.EXAMPLE
Restore-DbaDatabase -SqlServer server1\instance1 -Path c:\backups -DestinationDataDirectory c:\DataFiles -DestinationLogDirectory c:\LogFile

Scans all the files in c:\backups and then restores them onto the SQL Server Instance server1\instance1, placing data files
c:\DataFiles and all the log files into c:\LogFiles
 
.EXAMPLE
$File = Get-ChildItem c:\backups, \\server1\backups -recurse 
$File | Restore-DbaDatabase -SqlServer Server1\Instance -UseDestinationDefaultDirectories

This will take all of the files found under the folders c:\backups and \\server1\backups, and pipeline them into
Restore-DbaDatabase. Restore-DbaDatabase will then scan all of the files, and restore all of the databases included
to the latest point in time covered by their backups. All data and log files will be moved to the default SQL Sever 
folder for those file types as defined on the target instance.

#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[object[]]$Path,
		[parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[System.Management.Automation.PSCredential]$SqlCredential,
		[string]$DatabaseName,
		[String]$DestinationDataDirectory,
		[String]$DestinationLogDirectory,
		[DateTime]$RestoreTime = (Get-Date).addyears(1),
		[switch]$NoRecovery,
		[switch]$WithReplace,
		[Switch]$XpDirTree,
		[switch]$OutputScriptOnly,
		[switch]$VerifyOnly,
		[switch]$MaintenanceSolutionBackup,
		[hashtable]$FileMapping,
		[switch]$IgnoreLogBackup,
		[switch]$UseDestinationDefaultDirectories,
		[switch]$ReuseSourceFolderStructure,
		[string]$DestinationFilePrefix = ''
	)
	BEGIN
	{
		$base = $SqlServer.Split("\")[0]
		
		if ($base -eq "." -or $base -eq "localhost" -or $base -eq $env:computername -or $base -eq "127.0.0.1")
		{
			$islocal = $true
		}
		
		$FunctionName = $FunctionName = (Get-PSCallstack)[0].Command
		$BackupFiles = @()
		$UseDestinationDefaultDirectories = $true
		#Check compatible relocation options used:
		
		$ParamCount = 0
		if ($null -ne $FileMapping)
		{
			$ParamCount += 1
		}
		if ($ReuseSourceFolderStructure)
		{
			$ParamCount += 1
		}
		if ('' -ne $DestinationDataDirectory)
		{
			$ParamCount += 1
		}
		if ($ParamCount -gt 1)
		{
			Write-Warning "$FunctionName - $Paramcount You've specified incompatible Location parameters. Please only specify one of FileMapping,$ReuseSourceFolderStructure or DestinationDataDirectory"
			break
		}
		
		if ($DestinationLogDirectory -ne '' -and $ReuseSourceFolderStructure)
		{
			Write-Warning  "$FunctionName - DestinationLogDirectory and UseDestinationDefaultDirectories are mutually exclusive"
			break
		}
		if ($DestinationLogDirectory -ne '' -and $DestinationDataDirectory -eq '')
		{
			Write-Warning  "$FunctionName - DestinationLogDirectory can only be specified with DestinationDataDirectory"
			break
		}
		if (($null -ne $FileMapping) -or $ReuseSourceFolderStructure -or ($DestinationDataDirectory -ne ''))
		{
			$UseDestinationDefaultDirectories = $false
		}
		
	}
	PROCESS
	{
		foreach ($f in $path)
		{
			
			
			if ($f.StartsWith("\\") -eq $false -and $islocal -ne $true)
			{
				# Many internal functions parse using Get-ChildItem. 
				# We need to use Test-SqlPath and other commands instead
				# Prevent people from trying 
				
				Write-Warning "Currently, you can only use UNC paths when running this command remotely. We expect to support non-UNC paths for remote servers shortly."
				continue
				
				#$newpath = Join-AdminUnc $SqlServer "$path"
				#Write-Warning "Run this command on the server itself or try $newpath."
			}
			
			Write-Verbose "type = $($f.gettype())"
			if ($f -is [string])
			{
				Write-Verbose "$FunctionName : Paths passed in"
				foreach ($p in $f)
				{
					if ($XpDirTree)
					{
						$BackupFiles += Get-XPDirTreeRestoreFile -Path $p -SqlServer $SqlServer -SqlCredential $SqlCredential
					}
					elseif ((Get-Item $p).PSIsContainer -ne $true)
					{
						Write-Verbose "$FunctionName : Single file"
						$BackupFiles += Get-item $p
					}
					elseif ($MaintenanceSolutionBackup)
					{
						Write-Verbose "$FunctionName : Ola Style Folder"
						$BackupFiles += Get-OlaHRestoreFile -Path $p
					}
					else
					{
						Write-Verbose "$FunctionName : Standard Directory"
						$FileCheck = $BackupFiles.count
						$BackupFiles += Get-DirectoryRestoreFile -Path $p
						if ((($BackupFiles.count) - $FileCheck) -eq 0)
						{
							$BackupFiles += Get-OlaHRestoreFile -Path $p
						}
					}
				}
			}
			elseif (($f -is [System.IO.FileInfo]) -or ($f -is [System.Object] -and $f.FullName.Length -ne 0))
			{
				Write-Verbose "$FunctionName : Files passed in $($Path.count)"
				Foreach ($FileTmp in $Path)
				{
					$BackupFiles += $FileTmp
				}
			}
		}
	}
	END
	{
		try
		{
			$Server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
		}
		catch
		{
			$server.ConnectionContext.Disconnect()
			Write-Warning "$FunctionName - Cannot connect to $SqlServer" -WarningAction Stop
		}
		if ($null -ne $DatabaseName)
		{
			If (($null -ne $Server.Databases[$DatabaseName]) -and ($WithReplace -eq $false))
			{
				Write-Warning "$FunctionName - $DatabaseName exists on Sql Instance $SqlServer , must specify WithReplace to continue"
				break
			}
		}
		$server.ConnectionContext.Disconnect()
		$AllFilteredFiles = $BackupFiles | Get-FilteredRestoreFile -SqlServer:$SqlServer -RestoreTime:$RestoreTime -SqlCredential:$SqlCredential -IgnoreLogBackup:$IgnoreLogBackup
		Write-Verbose "$FunctionName - $($AllFilteredFiles.count) dbs to restore"
		
		ForEach ($FilteredFileSet in $AllFilteredFiles)
		{
			$FilteredFiles = $FilteredFileSet.values
			
			Write-Verbose "$FunctionName - Starting FileSet"
			if (($FilteredFiles.DatabaseName | Group-Object | Measure-Object).count -gt 1)
			{
				$dbs = ($FilteredFiles | Select-Object -Property DatabaseName) -join (',')
				Write-Warning "$FunctionName - We can only handle 1 Database at a time - $dbs"
				break
			}
			
			IF ($DatabaseName -eq '')
			{
				$DatabaseName = ($FilteredFiles | Select-Object -Property DatabaseName -unique).DatabaseName
				Write-Verbose "$FunctionName - Dbname set from backup = $DatabaseName"
			}
			
			if ((Test-DbaLsnChain -FilteredRestoreFiles $FilteredFiles) -and (Test-DbaRestoreVersion -FilteredRestoreFiles $FilteredFiles -SqlServer $SqlServer -SqlCredential $SqlCredential))
			{
				try
				{
					$FilteredFiles | Restore-DBFromFilteredArray -SqlServer $SqlServer -DBName $databasename -SqlCredential $SqlCredential -RestoreTime $RestoreTime -DestinationDataDirectory $DestinationDataDirectory -DestinationLogDirectory $DestinationLogDirectory -NoRecovery:$NoRecovery -Replace:$WithReplace -ScriptOnly:$OutputScriptOnly -FileStructure:$FileMapping -VerifyOnly:$VerifyOnly -UseDestinationDefaultDirectories:$UseDestinationDefaultDirectories -ReuseSourceFolderStructure:$ReuseSourceFolderStructure -DestinationFilePrefix:$DestinationFilePrefix
					
					$Completed = 'successfully'
				}
				catch
				{
					Write-Exception $_
					$Completed = 'unsuccessfully'
					return
				}
				Finally
				{
					Write-Verbose "Database $databasename restored $Completes"
				}
			}
			$DatabaseName = ''
		}
	}
}


