﻿Function Restore-DBFromFilteredArray
{
<# 
	.SYNOPSIS
	Internal function. Restores .bak file to SQL database. Creates db if it doesn't exist. $filestructure is
	a custom object that contains logical and physical file locations.
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
        [parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object]$SqlServer,
		[string]$DbName,
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$Files,
        [String]$DestinationDataDirectory,
		[String]$DestinationLogDirectory,
		[String]$DestinationFilePrefix,
        [DateTime]$RestoreTime = (Get-Date).addyears(1),  
		[switch]$NoRecovery,
		[switch]$ReplaceDatabase,
		[switch]$Scripts,
        [switch]$ScriptOnly,
		[switch]$VerifyOnly,
		[object]$filestructure,
		[System.Management.Automation.PSCredential]$SqlCredential,
		[switch]$UseDestinationDefaultDirectories,
		[switch]$ReuseSourceFolderStructure,
		[switch]$Force
	)
    
	    Begin
    {
        $FunctionName =(Get-PSCallstack)[0].Command
        Write-Verbose "$FunctionName - Starting"



        $Results = @()
        $InternalFiles = @()
		$Output = @()

    }
    process
        {

        foreach ($File in $Files){
            $InternalFiles += $File
        }
    }
    End
    {
		try 
		{
			$Server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential	
		}
		catch {
			$server.ConnectionContext.Disconnect()
			Write-Warning "$FunctionName - Cannot connect to $SqlServer" 
			break

		}
		
		$ServerName = $Server.name
		$Server.ConnectionContext.StatementTimeout = 0
		$Restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
		$Restore.ReplaceDatabase = $ReplaceDatabase
		
		if ($UseDestinationDefaultDirectories)
		{
			$DestinationDataDirectory = Get-SqlDefaultPaths $Server data
			$DestinationLogDirectory = Get-SqlDefaultPaths $Server log
		}

		If ($DbName -in $Server.databases.name -and $ScriptOnly -eq $false)
		{
			If ($ReplaceDatabase -eq $true)
			{	
				if($Pscmdlet.ShouldProcess("Killing processes in $dbname on $SqlServer as it exists and WithReplace specified  `n","Cannot proceed if processes exist, ","Database Exists and WithReplace specified, need to kill processes to restore"))			
				{
					try
					{
						Write-Verbose "$FunctionName - Set $DbName single_user to kill processes"
						Stop-DbaProcess -SqlServer $Server -Databases $Dbname -WarningAction Silentlycontinue
						Invoke-SQLcmd2 -ServerInstance:$SqlServer -Credential:$SqlCredential -query "Alter database $DbName set offline with rollback immediate; Alter database $DbName set online with rollback immediate" -database master

					}
					catch
					{
						Write-Verbose "$FunctionName - No processes to kill"
					}
				} 
			}
			else
			{
				Write-Warning "$FunctionName - Database exists and will not be overwritten without the WithReplace switch"
				break
			}

		}

 		$RestorePoints  = @()
        $if = $InternalFiles | Where-Object {$_.BackupTypeDescription -eq 'Database'} | Group-Object FirstLSN
		$RestorePoints  += @([PSCustomObject]@{order=[int64]1;'Files' = $if.group})
        $if = $InternalFiles | Where-Object {$_.BackupTypeDescription -eq 'Database Differential'}| Group-Object FirstLSN
		if ($if -ne $null){
			$RestorePoints  += @([PSCustomObject]@{order=[int64]2;'Files' = $if.group})
		}
		foreach ($if in ($InternalFiles | Where-Object {$_.BackupTypeDescription -eq 'Transaction Log'} | Group-Object FirstLSN))
 		{
   			$RestorePoints  += [PSCustomObject]@{order=[int64]($if.Name); 'Files' = $if.group}
		}
		$SortedRestorePoints = $RestorePoints | Sort-object -property order
		foreach ($RestorePoint in $SortedRestorePoints)
		{
			$RestoreFiles = $RestorePoint.files
			$RestoreFileNames = $RestoreFiles.BackupPath -join '`n ,'
			Write-verbose "$FunctionName - Restoring backup starting at order $($RestorePoint.order) - LSN $($RestoreFiles[0].FirstLSN) in $($RestoreFiles[0].BackupPath)"
			$LogicalFileMoves = @()
			if ($Restore.RelocateFiles.count -gt 0)
			{
				$Restore.RelocateFiles.Clear()
			}
				if ($DestinationDataDirectory -ne '' -and $FileStructure -eq $NUll)
				{
					if ($DestinationDataDirectory[-1] -eq '\')
					{
						$DestinationDataDirectory = $DestinationDataDirectory.Substring(0,($DestinationDataDirectory.length -1))
					}
					if ($DestinationLogDirectory[-1] -eq '\')
					{
						$DestinationLogDirectory = $DestinationLogDirectory.Substring(0,($DestinationLogDirectory.length -1))
					}
					foreach ($File in $RestoreFiles[0].Filelist)
			        {
                        $MoveFile = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile
                        $MoveFile.LogicalFileName = $File.LogicalName
                        if ($File.Type -eq 'L' -and $DestinationLogDirectory -ne '')
                        {
                            $MoveFile.PhysicalFileName = $DestinationLogDirectory + '\' + $DestinationFilePrefix + (split-path $file.PhysicalName -leaf)					
                        }
                        else {
                            $MoveFile.PhysicalFileName = $DestinationDataDirectory + '\' + $DestinationFilePrefix + (split-path $file.PhysicalName -leaf)	
                        }
                        $LogicalFileMoves += "Relocating $($MoveFile.LogicalFileName) to $($MoveFile.PhysicalFileName)"
						$null = $Restore.RelocateFiles.Add($MoveFile)
                    }

				} 
                elseif ($DestinationDataDirectory -eq '' -and $FileStructure -ne $NUll)
				{

					foreach ($key in $FileStructure.keys)
					{
						$MoveFile = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile
						$MoveFile.LogicalFileName = $key
						$MoveFile.PhysicalFileName = $filestructure[$key]

						$null = $Restore.RelocateFiles.Add($MoveFile)
						$LogicalFileMoves += "Relocating $($MoveFile.LogicalFileName) to $($MoveFile.PhysicalFileName)"
					}	
				} 
                elseif ($DestinationDataDirectory -ne '' -and $FileStructure -ne $NUll)
				{
					Write-Warning "$FunctionName - Conflicting options only one of FileStructure or DestinationDataDirectory allowed"
                    break
				} 
				$LogicalFileMovesString = $LogicalFileMoves -join ", `n"


				Write-Verbose "$FunctionName - Beginning Restore"
				$percent = [Microsoft.SqlServer.Management.Smo.PercentCompleteEventHandler] {
					Write-Progress -id 1 -activity "Restoring $dbname to $servername" -percentcomplete $_.Percent -status ([System.String]::Format("Progress: {0} %", $_.Percent))
				}
				$Restore.add_PercentComplete($percent)
				$Restore.PercentCompleteNotification = 1
				$Restore.add_Complete($complete)
				$Restore.ReplaceDatabase = $ReplaceDatabase
				if ($RestoreTime -gt (Get-Date))
				{
						$restore.ToPointInTime = $null
						Write-Verbose "$FunctionName - restoring to latest point in time"

				}
				elseif ($RestoreFiles[0].RecoveryModel -ne 'Simple')
				{
					$Restore.ToPointInTime = $RestoreTime
					Write-Verbose "$FunctionName - restoring to $RestoreTime"
					
				} 
				else 
				{
					Write-Verbose "$FunctionName - Restoring a Simple mode db, no restoretime"	
				}
				if ($DbName -ne '')
				{
					$Restore.Database = $DbName
				}
				else
				{
					$Restore.Database = $RestoreFiles[0].DatabaseName
				}
				$Action = switch ($RestoreFiles[0].BackupType)
					{
						'1' {'Database'}
						'2' {'Log'}
						'5' {'Database'}
						Default {'Unknown'}
					}
				Write-Verbose "$FunctionName - restore action = $Action"
				$restore.Action = $Action 
				if ($RestorePoint -eq $RestorePoints[-1] -and $NoRecovery -ne $true)
				{
					#Do recovery on last file
					Write-Verbose "$FunctionName - Doing Recovery on last file"
					$Restore.NoRecovery = $false
				}
				else 
				{
					Write-Verbose "$FunctionName - More files to restore, NoRecovery set"
					$Restore.NoRecovery = $true
				}
				Foreach ($RestoreFile in $RestoreFiles)
				{
					Write-Verbose "$FunctionName - Adding device"
					$Device = New-Object -TypeName Microsoft.SqlServer.Management.Smo.BackupDeviceItem
					$Device.Name = $RestoreFile.BackupPath
					$Device.devicetype = "File"
					$Restore.Devices.Add($device)
				}
				Write-Verbose "$FunctionName - Performing restore action"
		$ConfirmMessage = "`n Restore Database $DbName on $SqlServer `n from files: $RestoreFileNames `n with these file moves: `n $LogicalFileMovesString `n $ConfirmPointInTime `n"
		If ($Pscmdlet.ShouldProcess("$DBName on $SqlServer `n `n",$ConfirmMessage))
		{
			try
			{
				$RestoreComplete = $true
				if ($ScriptOnly)
				{
					$script = $restore.Script($server)
				}
				elseif ($VerifyOnly)
				{
					Write-Progress -id 1 -activity "Verifying $dbname backup file on $servername" -percentcomplete 0 -status ([System.String]::Format("Progress: {0} %", 0))
					$Verify = $restore.sqlverify($server)
					Write-Progress -id 1 -activity "Verifying $dbname backup file on $servername" -status "Complete" -Completed
					
					if ($verify -eq $true)
					{
						return "Verify successful"
					}
					else
					{
						return "Verify failed"
					}
				}
				else
				{
					Write-Progress -id 1 -activity "Restoring $DbName to ServerName" -percentcomplete 0 -status ([System.String]::Format("Progress: {0} %", 0))
					$Restore.sqlrestore($Server)
					$script = $restore.Script($Server)
					Write-Progress -id 1 -activity "Restoring $DbName to $ServerName" -status "Complete" -Completed
					
				}
		
			}
			catch
			{
				write-verbose "$FunctionName - Failed, Closing Server connection"
				$RestoreComplete = $False
				$ExitError = $_.Exception.InnerException
				Write-Warning "$FunctionName - $ExitError" -WarningAction stop
				#Exit as once one restore has failed there's no point continuing
				break
				
			}
			finally
			{	
				[PSCustomObject]@{
                    SqlInstance = $SqlServer
                    DatabaseName = $DatabaseName
                    DatabaseOwner = $server.ConnectionContext.TrueLogin
					NoRecovery = $restore.NoRecovery
					WithReplace = $ReplaceDatabase
					RestoreComplete  = $RestoreComplete
                    BackupFilesCount = $RestoreFiles.Count
                    RestoredFilesCount = $RestoreFiles[0].Filelist.PhysicalName.count
                    BackupSizeMB = ($RestoreFiles | measure-object -property BackupSizeMb -Sum).sum
                    CompressedBackupSizeMB = ($RestoreFiles | measure-object -property CompressedBackupSizeMb -Sum).sum
                    BackupFile = $RestoreFiles.BackupPath -join ','
					RestoredFile = (Split-Path $Restore.RelocateFiles.PhysicalFileName -Leaf) -join ','
					RestoredFileFull = $RestoreFiles[0].Filelist.PhysicalName -join ','
					RestoreDirectory = ((Split-Path $Restore.RelocateFiles.PhysicalFileName) | sort-Object -unique) -join ','
					BackupSize = ($RestoreFiles | measure-object -property BackupSize -Sum).sum
					CompressedBackupSize = ($RestoreFiles | measure-object -property CompressedBackupSize -Sum).sum
                    TSql = $script  
					BackupFileRaw = $RestoreFiles
					ExitError = $ExitError				
                } | Select-DefaultView -ExcludeProperty BackupSize, CompressedBackupSize, ExitError, BackupFileRaw, RestoredFileFull 
				while ($Restore.Devices.count -gt 0)
				{
					$device = $restore.devices[0]
					$null = $restore.devices.remove($Device)
				}
				write-verbose "$FunctionName - Succeeded, Closing Server connection"
				$server.ConnectionContext.Disconnect()
			}
		}	
		}
		if ($server.ConnectionContext.exists)
		{
			$server.ConnectionContext.Disconnect()
		}
	}
}
