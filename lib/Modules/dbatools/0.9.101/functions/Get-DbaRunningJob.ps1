function Get-DbaRunningJob {
	<#
		.SYNOPSIS
			Returns all non-idle Agent jobs running on the server.

		.DESCRIPTION
			This function returns agent jobs that active on the SQL Server instance when calling the command. The information is gathered the SMO JobServer.jobs and be returned either in detailed or standard format.

 		.PARAMETER SqlInstance
			The SQL Server instance to connect to.

        .PARAMETER SqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

			$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

			Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.NOTES 
			Tags:
			Author: Stephen Bennett, https://sqlnotesfromtheunderground.wordpress.com/
			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Get-DbaRunningJob

		.EXAMPLE
			Get-DbaRunningJob -SqlInstance localhost

			Returns any active jobs on localhost.

		.EXAMPLE
			Get-DbaRunningJob -SqlInstance localhost -Detailed

			Returns a detailed output of any active jobs on localhost.

		.EXAMPLE
			'localhost','localhost\namedinstance' | Get-DbaRunningJob

			Returns all active jobs on multiple instances piped into the function.
	#>
	[CmdletBinding()]
	Param (
		[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
		[Alias("ServerInstance", "SqlServer", "SqlServers")]
		[DbaInstanceParameter[]]$SqlInstance,
		[Alias("Credential")]
		[PSCredential]$SqlCredential,
		[switch][Alias('Silent')]$EnableException
	)
	process {
		foreach ($instance in $SqlInstance) {
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
			}
			catch {
				Stop-Function -Message "Failed to connect to: $Server." -Target $server -ErrorRecord $_ -Continue
			}
			
			$jobs = $server.JobServer.jobs | Where-Object { $_.CurrentRunStatus -ne 'Idle' }
			
			if (!$jobs) {
				Write-Message -Level Verbose -Message "No Jobs are currently running on: $Server."
			}
			else {
				foreach ($job in $jobs) {
					[pscustomobject]@{
						ComputerName     = $server.NetName
						InstanceName     = $server.ServiceName
						SqlInstance      = $server.DomainInstanceName
						Name             = $job.name
						Category         = $job.Category
						CurrentRunStatus = $job.CurrentRunStatus
						CurrentRunStep   = $job.CurrentRunStep
						HasSchedule      = $job.HasSchedule
						LastRunDate      = $job.LastRunDate
						LastRunOutcome   = $job.LastRunOutcome
						JobStep          = $job.JobSteps
					}
				}
			}
		}
	}
}