#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#
function Test-DbaSqlPath {
	<#
		.SYNOPSIS
			Tests if file or directory exists from the perspective of the SQL Server service account.

		.DESCRIPTION
			Uses master.dbo.xp_fileexist to determine if a file or directory exists.

		.PARAMETER SqlInstance
			The SQL Server you want to run the test on.

		.PARAMETER SqlCredential
 			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

			$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

			Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER Path
			The Path to test. This can be a file or directory

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.OUTPUTS
			System.Boolean

		.NOTES
			Tags: Path, ServiceAccount
			Author: Chrissy LeMaire (@cl), netnerds.net
			Requires: Admin access to server (not SQL Services),
			Remoting must be enabled and accessible if $SqlInstance is not local

			dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
			Copyright (C) 2016 Chrissy LeMaire
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Test-DbaSqlPath

		.EXAMPLE
			Test-DbaSqlPath -SqlInstance sqlcluster -Path L:\MSAS12.MSSQLSERVER\OLAP

			Tests whether the service account running the "sqlcluster" SQL Server instance can access L:\MSAS12.MSSQLSERVER\OLAP. Logs into sqlcluster using Windows credentials.

		.EXAMPLE
			$credential = Get-Credential
			Test-DbaSqlPath -SqlInstance sqlcluster -SqlCredential $credential -Path L:\MSAS12.MSSQLSERVER\OLAP

			Tests whether the service account running the "sqlcluster" SQL Server instance can access L:\MSAS12.MSSQLSERVER\OLAP. Logs into sqlcluster using SQL authentication.

	#>
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstance[]]$SqlInstance,
		[PSCredential]$SqlCredential,
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[switch][Alias('Silent')]$EnableException
	)

	process {
		foreach ($instance in $SqlInstance) {
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}

			Write-Message -Level VeryVerbose -Message "Checking access to $path for $instance."
			$sql = "EXEC master.dbo.xp_fileexist '$path'"
			try {
				Write-Message -Level Debug -Message "Executing: $sql."
				$fileExist = $server.Query($sql)
			}

			catch {
				Stop-Function -Message "Failed to test the path $Path." -ErrorRecord $_ -Target $instance -Continue
			}
			if ($fileExist[0] -eq 1 -or $fileExist[1] -eq 1) {
				return $true
			}
			else {
				return $false
			}
		}
	}
	end {
		Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Test-SqlPath
	}
}
