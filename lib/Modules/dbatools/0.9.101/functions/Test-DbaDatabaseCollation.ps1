function Test-DbaDatabaseCollation {
	<#
		.SYNOPSIS
			Compares Database Collations to Server Collation

		.DESCRIPTION
			Compares Database Collations to Server Collation

        .PARAMETER SqlInstance
            The target SQL Server instance or instances.

        .PARAMETER SqlCredential
            Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

            $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

            Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

            To connect as a different Windows user, run PowerShell as that user.
	
		.PARAMETER Database
			Specifies the database(s) to process. Options for this list are auto-populated from the server. If unspecified, all databases will be processed.
		
		.PARAMETER ExcludeDatabase
			Specifies the database(s) to exclude from processing. Options for this list are auto-populated from the server.
		
		.PARAMETER Detailed
			Does nothing, this is deprecatated. Now Detailed is the default.

	    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
	
		.NOTES
			Tags: Database, Collation
			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Test-DbaDatabaseCollation

		.EXAMPLE
			Test-DbaDatabaseCollation -SqlInstance sqlserver2014a

			Returns server name, database name and true/false if the collations match for all databases on sqlserver2014a.

		.EXAMPLE
			Test-DbaDatabaseCollation -SqlInstance sqlserver2014a -Database db1, db2

			Returns detailed inforamtion for the db1 and db2 databases on sqlserver2014a.

		.EXAMPLE
			Test-DbaDatabaseCollation -SqlInstance sqlserver2014a, sql2016 -Exclude db1

			Returns detailed information for database and server collations for all databases except db1 on sqlserver2014a and sql2016.

		.EXAMPLE
			Get-DbaRegisteredServer -SqlInstance sql2016 | Test-DbaDatabaseCollation

			Returns db/server collation information for every database on every server listed in the Central Management Server on sql2016.
	#>
	[CmdletBinding()]
	Param (
		[parameter(Mandatory, ValueFromPipeline)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstanceParameter[]]$SqlInstance,
		[Alias("Credential")]
		[PSCredential]$SqlCredential,
		[Alias("Databases")]
		[object[]]$Database,
		[object[]]$ExcludeDatabase,
		[switch]$Detailed,
		[switch]$EnableException
	)
	begin {
		Test-DbaDeprecation -DeprecatedOn "1.0.0" -Parameter "Detailed"
	}
	process {
		foreach ($instance in $sqlinstance) {
			# Try connecting to the instance
			Write-Message -Message "Attempting to connect to $instance" -Level Verbose
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}
			
			$dbs = $server.Databases
			
			if ($Database) {
				$dbs = $dbs | Where-Object { $Database -contains $_.Name }
			}
			
			if ($ExcludeDatabase) {
				$dbs = $dbs | Where-Object Name -NotIn $ExcludeDatabase
			}
			
			foreach ($db in $dbs) {
				Write-Message -Level Verbose -Message "Processing $($db.name) on $servername."
				[PSCustomObject]@{
					ComputerName	 = $server.NetName
					InstanceName	 = $server.ServiceName
					SqlInstance	     = $server.DomainInstanceName
					Database		 = $db.name
					ServerCollation  = $server.collation
					DatabaseCollation = $db.collation
					IsEqual		     = $db.collation -eq $server.collation
				}
			}
		}
	}
}