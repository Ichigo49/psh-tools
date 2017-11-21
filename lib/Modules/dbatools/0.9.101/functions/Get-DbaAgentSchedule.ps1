function Get-DbaAgentSchedule {
	<#
		.SYNOPSIS
			Returns all SQL Agent Shared Schedules on a SQL Server Agent.

		.DESCRIPTION
			This function returns SQL Agent Shared Schedules.

		.PARAMETER SqlInstance
			SqlInstance name or SMO object representing the SQL Server to connect to.
			This can be a collection and receive pipeline input.

		.PARAMETER SqlCredential
			PSCredential object to connect as. If not specified, current Windows login will be used.

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.NOTES
			Tags: Agent, Schedule
			Author: Chris McKeown (@devopsfu), http://www.devopsfu.com

			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Get-DbaAgentSchedule

		.EXAMPLE
			Get-DbaAgentSchedule -SqlInstance localhost

			Returns all SQL Agent Shared Schedules on the local default SQL Server instance

		.EXAMPLE
			Get-DbaAgentSchedule -SqlInstance localhost, sql2016

			Returns all SQL Agent Shared Schedules for the local and sql2016 SQL Server instances
	#>
	[CmdletBinding()]
	param (
		[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $True)]
		[Alias("ServerInstance", "Instance", "SqlServer")]
		[DbaInstanceParameter[]]$SqlInstance,
		[PSCredential]$SqlCredential,
		[switch][Alias('Silent')]$EnableException
	)

	process {
		foreach ($instance in $SqlInstance) {
			Write-Message -Level Verbose -Message "Attempting to connect to $instance"
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}

			if ($server.Edition -like 'Express*') {
				Stop-Function -Message "$($server.Edition) does not support SQL Server Agent. Skipping $server." -Continue
			}

			$defaults = "ComputerName", "InstanceName", "SqlInstance", "Name as ScheduleName", "ActiveEndDate", "ActiveEndTimeOfDay", "ActiveStartDate", "ActiveStartTimeOfDay", "DateCreated", "FrequencyInterval", "FrequencyRecurrenceFactor", "FrequencyRelativeIntervals", "FrequencySubDayInterval", "FrequencySubDayTypes", "FrequencyTypes", "IsEnabled", "JobCount"

			foreach ($schedule in $server.JobServer.SharedSchedules) {
				Add-Member -Force -InputObject $schedule -MemberType NoteProperty ComputerName -value $server.NetName
				Add-Member -Force -InputObject $schedule -MemberType NoteProperty InstanceName -value $server.ServiceName
				Add-Member -Force -InputObject $schedule -MemberType NoteProperty SqlInstance -value $server.DomainInstanceName

				Select-DefaultView -InputObject $schedule -Property $defaults
			}
		}
	}
}
