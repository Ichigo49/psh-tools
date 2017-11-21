function Get-DbaDbRecoveryModel {
    <#
        .SYNOPSIS 
            Get-DbaDbRecoveryModel displays the Recovery Model.

        .DESCRIPTION
            Get-DbaDbRecoveryModel displays the Recovery Model for all databases. This is the default, you can filter using -Database, -ExcludeDatabase, -RecoveryModel

        .PARAMETER SqlInstance
            The SQL Server instance.

        .PARAMETER SqlCredential
            Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

            $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

            Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

            To connect as a different Windows user, run PowerShell as that user.

        .PARAMETER Database
            The database(s) to process - this list is auto-populated from the server. if unspecified, all databases will be processed.

        .PARAMETER ExcludeDatabase
            The database(s) to exclude - this list is auto-populated from the server

        .PARAMETER RecoveryModel
            Filters the output based on Recovery Model. Valid options are Simple, Full and BulkLogged
            
            Details about the recovery models can be found here: 
            https://docs.microsoft.com/en-us/sql/relational-databases/backup-restore/recovery-models-sql-server

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Recovery, RecoveryModel, Simple, Full, Bulk, BulkLogged
            Author: Viorel Ciucu (@viorelciucu), https://www.cviorel.com

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

        .LINK
            https://dbatools.io/Get-DbaDbRecoveryModel

        .EXAMPLE
            Get-DbaDbRecoveryModel -SqlInstance sql2014 -RecoveryModel BulkLogged -Verbose

            Gets all databases on SQL Server instance sql2014 having RecoveryModel set to BulkLogged

        .EXAMPLE
            Get-DbaDbRecoveryModel -SqlInstance sql2014 -Database TestDB

            Gets recovery model information for TestDB. If TestDB does not exist on the instance we don't return anythig.

    #>
    [CmdletBinding()]
    param (
		[parameter(Mandatory, ValueFromPipeline)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstance[]]$SqlInstance,
		[PSCredential]$SqlCredential,
		[ValidateSet('Simple', 'Full', 'BulkLogged')]
		[string[]]$RecoveryModel,
		[object[]]$Database,
		[object[]]$ExcludeDatabase,
		[switch]$EnableException
	)
	begin {
		$defaults = 'ComputerName', 'InstanceName', 'SqlInstance', 'Name', 'Status', 'IsAccessible', 'RecoveryModel',
		'LastBackupDate as LastFullBackup', 'LastDifferentialBackupDate as LastDiffBackup',
		'LastLogBackupDate as LastLogBackup'
	}
	process {
		$params = @{
			SqlInstance	       = $SqlInstance
			SqlCredential	   = $SqlCredential
			Database		   = $Database
			ExcludeDatabase    = $ExcludeDatabase
			EnableException    = $EnableException
		}
		
		if ($RecoveryModel) {
			Get-DbaDatabase @params | Where-Object RecoveryModel -in $RecoveryModel | Select-DefaultView -Property $defaults
		}
		else {
			Get-DbaDatabase @params | Select-DefaultView -Property $defaults
		}
	}
}