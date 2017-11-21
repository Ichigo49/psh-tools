Function Invoke-DbaDatabaseUpgrade {
<#
	.SYNOPSIS
	Take a database and upgrades it to compatibility of the SQL Instance its hosted on. Based on https://thomaslarock.com/2014/06/upgrading-to-sql-server-2014-a-dozen-things-to-check/

	.DESCRIPTION
	Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views. 
		
	.PARAMETER SqlInstance
	The SQL Server that you're connecting to.

	.PARAMETER SqlCredential
	SqlCredential object used to connect to the SQL Server as a different user.

	.PARAMETER Database
	The database(s) to process - this list is autopopulated from the server. If unspecified, all databases will be processed.

	.PARAMETER ExcludeDatabase
	The database(s) to exclude - this list is autopopulated from the server

	.PARAMETER AllUserDatabases
	Run command against all user databases
	
	.PARAMETER Force
	Don't skip over databases that are already at the same level the instance is

	.PARAMETER NoCheckDb
	Skip checkdb

	.PARAMETER NoUpdateUsage
	Skip usage update

	.PARAMETER NoUpdateStats
	Skip stats update

	.PARAMETER NoRefreshView
	Skip view update
	
	.PARAMETER DatabaseCollection
	A collection of databases (such as returned by Get-DbaDatabase)
	
	.PARAMETER WhatIf
	Shows what would happen if the command were to run

	.PARAMETER Confirm
	Prompts for confirmation of every step. For example:

	Are you sure you want to perform this action?
	Performing the operation "Update database" on target "pubs on SQL2016\VNEXT".
	[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):

	.PARAMETER EnableException
	By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
	This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
	Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
	
	.NOTES
		Author: Stephen Bennett, https://sqlnotesfromtheunderground.wordpress.com/
		Tags: Shrink, Databases

		Website: https://dbatools.io
		Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
		License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

	
	.LINK
	    https://dbatools.io/Invoke-DbaDatabaseUpgrade

	.EXAMPLE
		Invoke-DbaDatabaseUpgrade -SqlInstance PRD-SQL-MSD01 -Database Test
		
		Runs the below processes against the databases
		-- Puts compatibility of database to level of SQL Instance
		-- Runs CHECKDB DATA_PURITY
		-- Runs DBCC UPDATESUSAGE
		-- Updates all users statistics
		-- Runs sp_refreshview against every view in the database

	.EXAMPLE
		Invoke-DbaDatabaseUpgrade -SqlInstance PRD-SQL-INT01 -Database Test -NoRefreshView
		
		Runs the upgrade command skipping the sp_refreshview update on all views
	
	.EXAMPLE
		Invoke-DbaDatabaseUpgrade -SqlInstance PRD-SQL-INT01 -Database Test -Force
		
		If database Test is already at the correct compatibility, runs every necessary step
	
	.EXAMPLE
		Get-DbaDatabase -SqlInstance sql2016 | Out-GridView -Passthru | Invoke-DbaDatabaseUpgrade
		
		Get only specific databases using GridView and pass those to Invoke-DbaDatabaseUpgrade
#>
	[CmdletBinding(SupportsShouldProcess)]
	Param (
		[parameter(Position = 0)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstanceParameter[]]$SqlInstance,
		[System.Management.Automation.PSCredential]$SqlCredential,
		[object[]]$Database,
		[object[]]$ExcludeDatabase,
		[switch]$NoCheckDb,
		[switch]$NoUpdateUsage,
		[switch]$NoUpdateStats,
		[switch]$NoRefreshView,
		[switch]$AllUserDatabases,
		[switch]$Force,
		[parameter(ValueFromPipeline)]
		[Microsoft.SqlServer.Management.Smo.Database[]]$DatabaseCollection,
		[switch][Alias('Silent')]$EnableException
	)
	process {
		
		if (Test-Bound -not 'SqlInstance','DatabaseCollection') {
			Write-Message -Level Warning -Message "You must specify either a SQL instance or pipe a database collection"
			continue
		}
		
		if (Test-Bound -not 'Database', 'DatabaseCollection', 'ExcludeDatabase', 'AllUserDatabases') {
			Write-Message -Level Warning -Message "You must explicitly specify a database. Use -Database, -ExcludeDatabase, -AllUserDatabases or pipe a database collection"
			continue
		}
		
		foreach ($instance in $SqlInstance) {
			try {
				Write-Message -Level VeryVerbose -Message "Connecting to <c='green'>$instance</c>" -Target $instance
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
				$server.ConnectionContext.StatementTimeout = [Int32]::MaxValue
			}
			catch {
				Stop-Function -Message "Failed to process Instance $Instance" -ErrorRecord $_ -Target $instance -Continue
			}
			$DatabaseCollection += $server.Databases
		}
		
		$DatabaseCollection =  $DatabaseCollection | Where-Object { $_.IsSystemObject -eq $false }
		if ($Database) {
			$DatabaseCollection = $DatabaseCollection | Where-Object { $_.Name -contains $Database }
		}
		if ($ExcludeDatabase) {
			$DatabaseCollection = $DatabaseCollection | Where-Object { $_.Name -notcontains $ExcludeDatabase }
		}
		
		foreach ($db in $DatabaseCollection) {
			# create objects to use in updates
			$server = $db.Parent
			$ServerVersion = $server.VersionMajor
			Write-Message -Level Verbose -Message "SQL Server is using Version: $ServerVersion"
			
			$ogcompat = $db.CompatibilityLevel
			$dbname = $db.Name
			$dbversion = switch ($db.CompatibilityLevel) {
					"Version100"  { 10 } # SQL Server 2008
					"Version110"  { 11 } # SQL Server 2012
					"Version120"  { 12 } # SQL Server 2014
					"Version130"  { 13 } # SQL Server 2016
					"Version140"  { 14 } # SQL Server 2017
					default { 9 } # SQL Server 2005
				}
			if (-not $Force) {
				# skip over databases at the correct level, unless -Force
				if ($dbversion -ge $ServerVersion) {
					Write-Message -Level VeryVerbose -Message "Skipping $db because compatibility is at the correct level. Use -Force if you want to run all the additional steps"
					continue
				}
			}
			Write-Message -Level Verbose -Message "Updating $db compatibility to SQL Instance level"
			if ($dbversion -lt $ServerVersion) {
				If ($Pscmdlet.ShouldProcess($server, "Updating $db version on $server from $dbversion to $ServerVersion")) {
					$Comp = $ServerVersion * 10
					$tsqlComp = "ALTER DATABASE $db SET COMPATIBILITY_LEVEL = $Comp"
					try {
						$db.ExecuteNonQuery($tsqlComp)
						$comResult = $Comp
					}
					catch {
						Write-Message -Level Warning -Message "Failed run Compatibility Upgrade" -ErrorRecord $_ -Target $instance
						$comResult = "Fail"
					}
				}
			}
			else {
				$comResult = "No change"
			}
			
			if (!($NoCheckDb)) {
				Write-Message -Level Verbose -Message "Updating $db with DBCC CHECKDB DATA_PURITY"
				If ($Pscmdlet.ShouldProcess($server, "Updating $db with DBCC CHECKDB DATA_PURITY")) {
					$tsqlCheckDB = "DBCC CHECKDB ('$dbname') WITH DATA_PURITY, NO_INFOMSGS"
					try {
						$db.ExecuteNonQuery($tsqlCheckDB)
						$DataPurityResult = "Success"
					}
					catch {
						Write-Message -Level Warning -Message "Failed run DBCC CHECKDB with DATA_PURITY on $db" -ErrorRecord $_ -Target $instance
						$DataPurityResult = "Fail"
					}
				}
			}
			else {
				Write-Message -Level Verbose -Message "Ignoring CHECKDB DATA_PURITY"
			}
			
			if (!($NoUpdateUsage)) {
				Write-Message -Level Verbose -Message "Updating $db with DBCC UPDATEUSAGE"
				If ($Pscmdlet.ShouldProcess($server, "Updating $db with DBCC UPDATEUSAGE")) {
					$tsqlUpdateUsage = "DBCC UPDATEUSAGE ($db) WITH NO_INFOMSGS;"
					try {
						$db.ExecuteNonQuery($tsqlUpdateUsage)
						$UpdateUsageResult = "Success"
					}
					catch {
						Write-Message -Level Warning -Message "Failed to run DBCC UPDATEUSAGE on $db" -ErrorRecord $_ -Target $instance
						$UpdateUsageResult = "Fail"
					}
				}
			}
			else {
				Write-Message -Level Verbose -Message "Ignore DBCC UPDATEUSAGE"
				$UpdateUsageResult = "Skipped"
			}
			
			if (!($NoUpdatestats)) {
				Write-Message -Level Verbose -Message "Updating $db statistics"
				If ($Pscmdlet.ShouldProcess($server, "Updating $db statistics")) {
					$tsqlStats = "EXEC sp_updatestats;"
					try {
						$db.ExecuteNonQuery($tsqlStats)
						$UpdateStatsResult = "Success"
					}
					catch {
						Write-Message -Level Warning -Message "Failed to run sp_updatestats on $db" -ErrorRecord $_ -Target $instance
						$UpdateStatsResult = "Fail"
					}
				}
			}
			else {
				Write-Message -Level Verbose -Message "Ignoring sp_updatestats"
				$UpdateStatsResult = "Skipped"
			}
			
			if (!($NoRefreshView)) {
				Write-Message -Level Verbose -Message "Refreshing $db Views"
				$dbViews = $db.Views | Where-Object IsSystemObject -eq $false
				$RefreshViewResult = "Success"
				foreach ($dbview in $dbviews) {
					$viewName = $dbView.Name
					$viewSchema = $dbView.Schema
					$fullName = $viewSchema + "." + $viewName
					
					$tsqlupdateView = "EXECUTE sp_refreshview N'$fullName';  "
					
					If ($Pscmdlet.ShouldProcess($server, "Refreshing view $fullName on $db")) {
						try {
							$db.ExecuteNonQuery($tsqlupdateView)
						}
						catch {
							Write-Message -Level Warning -Message "Failed update view $fullName on $db" -ErrorRecord $_ -Target $instance
							$RefreshViewResult = "Fail"
						}
					}
				}
			}
			else {
				Write-Message -Level Verbose -Message "Ignore View Refreshes"
				$RefreshViewResult = "Skipped"
			}
			
			If ($Pscmdlet.ShouldProcess("console", "Outputting object")) {
				$db.Refresh()
				
				[PSCustomObject]@{
					ComputerName = $server.NetName
					InstanceName = $server.ServiceName
					SqlInstance = $server.DomainInstanceName
					Database = $db.name
					OriginalCompatibility = $ogcompat.ToString().Replace('Version', '')
					CurrentCompatibility = $db.CompatibilityLevel.ToString().Replace('Version', '')
					Compatibility = $comResult
					DataPurity = $DataPurityResult
					UpdateUsage = $UpdateUsageResult
					UpdateStats = $UpdateStatsResult
					RefreshViews = $RefreshViewResult
				}
			}
		}
	}
}