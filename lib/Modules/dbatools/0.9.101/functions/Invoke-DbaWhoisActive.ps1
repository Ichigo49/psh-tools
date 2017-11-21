function Invoke-DbaWhoisActive {
	<#
.SYNOPSIS
Outputs results of Adam Machanic's sp_WhoIsActive DataTable

.DESCRIPTION
Output results of Adam Machanic's sp_WhoIsActive

This command was built with Adam's permission. To read more about sp_WhoIsActive, please visit:

Updates: http://sqlblog.com/blogs/adam_machanic/archive/tags/who+is+active/default.aspx

Also, consider donating to Adam if you find this stored procedure helpful: http://tinyurl.com/WhoIsActiveDonate

.PARAMETER SqlInstance
The SQL Server instance. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

.PARAMETER Database
The database where sp_WhoIsActive is installed. Defaults to master. If the sp_WhoIsActive is not installed, the command will warn and exit.

.PARAMETER Filter
FiltersBoth inclusive and exclusive
Set either filter to '' to disable
Session is a session ID, and either 0 or '' can be used to indicate "all" sessions
All other filter types support % or _ as wildcards

.PARAMETER FilterType
Valid filter types are: session, program, database, login, and host

.PARAMETER NotFilter
FiltersBoth inclusive and exclusive
Set either filter to '' to disable
Session is a session ID, and either 0 or '' can be used to indicate "all" sessions
All other filter types support % or _ as wildcards

.PARAMETER NotFilterType
Valid filter types are: session, program, database, login, and host

.PARAMETER ShowOwnSpid
Retrieve data about the calling session?

.PARAMETER ShowSystemSpids
Retrieve data about system sessions?

.PARAMETER ShowSleepingSpids
Controls how sleeping SPIDs are handled, based on the idea of levels of interest
0 does not pull any sleeping SPIDs
1 pulls only those sleeping SPIDs that also have an open transaction
2 pulls all sleeping SPIDs

.PARAMETER GetFullInnerText
If 1, gets the full stored procedure or running batch, when available
If 0, gets only the actual statement that is currently running in the batch or procedure

.PARAMETER GetPlans
Get associated query plans for running tasks, if available
If 1, gets the plan based on the request's statement offset
If 2, gets the entire plan based on the request's plan_handle

.PARAMETER GetOuterCommand
Get the associated outer ad hoc query or stored procedure call, if available

.PARAMETER GetTransactionInfo
Enables pulling transaction log write info and transaction duration

.PARAMETER GetTaskInfo
Get information on active tasks, based on three interest levels
Level 0 does not pull any task-related information
Level 1 is a lightweight mode that pulls the top non-CXPACKET wait, giving preference to blockers
Level 2 pulls all available task-based metrics, including:
number of active tasks, current wait stats, physical I/O, context switches, and blocker information

.PARAMETER GetLocks
Gets associated locks for each request, aggregated in an XML format

.PARAMETER GetAverageTime
Get average time for past runs of an active query
(based on the combination of plan handle, sql handle, and offset)

.PARAMETER GetAdditonalInfo
Get additional non-performance-related information about the session or request
text_size, language, date_format, date_first, quoted_identifier, arithabort, ansi_null_dflt_on,
ansi_defaults, ansi_warnings, ansi_padding, ansi_nulls, concat_null_yields_null,
transaction_isolation_level, lock_timeout, deadlock_priority, row_count, command_type

If a SQL Agent job is running, an subnode called agent_info will be populated with some or all of
the following: job_id, job_name, step_id, step_name, msdb_query_error (in the event of an error)

If @get_task_info is set to 2 and a lock wait is detected, a subnode called block_info will be
populated with some or all of the following: lock_type, database_name, object_id, file_id, hobt_id,
applock_hash, metadata_resource, metadata_class_id, object_name, schema_name

.PARAMETER FindBlockLeaders
Walk the blocking chain and count the number of
total SPIDs blocked all the way down by a given session
Also enables task_info Level 1, if @get_task_info is set to 0

.PARAMETER DeltaInterval
Pull deltas on various metrics
Interval in seconds to wait before doing the second data pull

.PARAMETER OutputColumnList
List of desired output columns, in desired order
Note that the final output will be the intersection of all enabled features and all
columns in the list. Therefore, only columns associated with enabled features will
actually appear in the output. Likewise, removing columns from this list may effectively
disable features, even if they are turned on

Each element in this list must be one of the valid output column names. Names must be
delimited by square brackets. White space, formatting, and additional characters are
allowed, as long as the list contains exact matches of delimited valid column names.

.PARAMETER SortOrder
Column(s) by which to sort output, optionally with sort directions.
Valid column choices:
session_id, physical_io, reads, physical_reads, writes, tempdb_allocations,
tempdb_current, CPU, context_switches, used_memory, physical_io_delta,
reads_delta, physical_reads_delta, writes_delta, tempdb_allocations_delta,
tempdb_current_delta, CPU_delta, context_switches_delta, used_memory_delta,
tasks, tran_start_time, open_tran_count, blocking_session_id, blocked_session_count,
percent_complete, host_name, login_name, database_name, start_time, login_time

Note that column names in the list must be bracket-delimited. Commas and/or white
space are not required.

.PARAMETER FormatOutput
Formats some of the output columns in a more "human readable" form
0 disables outfput format
1 formats the output for variable-width fonts
2 formats the output for fixed-width fonts

.PARAMETER DestinationTable
If set to a non-blank value, the script will attempt to insert into the specified destination table. Please note that the script will not verify that the table exists, or that it has the correct schema, before doing the insert. Table can be specified in one, two, or three-part format

.PARAMETER ReturnSchema
If set to 1, no data collection will happen and no result set will be returned; instead,
a CREATE TABLE statement will be returned via the @schema parameter, which will match
the schema of the result set that would be returned by using the same collection of the
rest of the parameters. The CREATE TABLE statement will have a placeholder token of
<table_name> in place of an actual table name.


.PARAMETER Schema
If set to 1, no data collection will happen and no result set will be returned; instead,
a CREATE TABLE statement will be returned via the @schema parameter, which will match
the schema of the result set that would be returned by using the same collection of the
rest of the parameters. The CREATE TABLE statement will have a placeholder token of
<table_name> in place of an actual table name.

.PARAMETER Help
Help! What do I do?

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use: $scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials. To connect as a different Windows user, run PowerShell as that user.

.PARAMETER WhatIf
Shows what would happen if the command were to run. No actions are actually performed.

.PARAMETER Confirm
Prompts you for confirmation before executing any changing operations within the command.

.PARAMETER EnableException
		By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
		This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
		Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		
.NOTES
Tags: Memory
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

.LINK
https://dbatools.io/Invoke-DbaWhoisActive

.EXAMPLE
Invoke-DbaWhoisActive -SqlInstance sqlserver2014a

Execute sp_whoisactive on sqlserver2014a. This command expects sp_WhoIsActive to be in the master database. Logs into the SQL Server with Windows credentials.

.EXAMPLE
Invoke-DbaWhoisActive -SqlInstance sqlserver2014a -SqlCredential $credential -Database dbatools

Execute sp_whoisactive on sqlserver2014a. This command expects sp_WhoIsActive to be in the dbatools database. Logs into the SQL Server with SQL Authentication.

.EXAMPLE
Invoke-DbaWhoisActive -SqlInstance sqlserver2014a -GetAverageTime

Similar to running sp_WhoIsActive @get_avg_time

.EXAMPLE
Invoke-DbaWhoisActive -SqlInstance sqlserver2014a -GetOuterCommand -FindBlockLeaders

Similar to running sp_WhoIsActive @get_outer_command = 1, @find_block_leaders = 1

#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('ServerInstance', 'SqlServer')]
		[DbaInstanceParameter[]]$SqlInstance,
		[PSCredential]
		$SqlCredential,
		[object]$Database,
		[Alias('As')]
		[ValidateLength(0, 128)]
		[string]$Filter,
		[ValidateSet('Session', 'Program', 'Database', 'Login', 'Host')]
		[string]$FilterType = 'Session',
		[ValidateLength(0, 128)]
		[string]$NotFilter,
		[ValidateSet('Session', 'Program', 'Database', 'Login', 'Host')]
		[string]$NotFilterType = 'Session',
		[switch]$ShowOwnSpid,
		[switch]$ShowSystemSpids,
		[ValidateRange(0, 255)]
		[int]$ShowSleepingSpids,
		[switch]$GetFullInnerText,
		[ValidateRange(0, 255)]
		[int]$GetPlans,
		[switch]$GetOuterCommand,
		[switch]$GetTransactionInfo,
		[ValidateRange(0, 2)]
		[int]$GetTaskInfo,
		[switch]$GetLocks,
		[switch]$GetAverageTime,
		[switch]$GetAdditonalInfo,
		[switch]$FindBlockLeaders,
		[ValidateRange(0, 255)]
		[int]$DeltaInterval,
		[ValidateLength(0, 8000)]
		[string]$OutputColumnList = '[dd%][session_id][sql_text][sql_command][login_name][wait_info][tasks][tran_log%][cpu%][temp%][block%][reads%][writes%][context%][physical%][query_plan][locks][%]',
		[ValidateLength(0, 500)]
		[string]$SortOrder = '[start_time] ASC',
		[ValidateRange(0, 255)]
		[int]$FormatOutput = 1,
		[ValidateLength(0, 4000)]
		[string]$DestinationTable = '',
		[switch]$ReturnSchema,
		[string]$Schema,
		[switch]$Help,
		[switch][Alias('Silent')]$EnableException
	)

	begin {
		$passedparams = $psboundparameters.Keys | Where-Object { 'Silent', 'SqlServer', 'SqlCredential', 'OutputAs', 'ServerInstance', 'SqlInstance', 'Database' -notcontains $_ }
		$localparams = $psboundparameters
	}

	process {

		foreach ($instance in $sqlinstance) {
			try {
				Write-Message -Level Verbose -Message "Connecting to $instance"
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}

			if ($server.VersionMajor -lt 9) {
				throw "sp_WhoIsActive is only supported in SQL Server 2005 and above"
			}

			$paramdictionary = @{
				Filter             = '@filter'
				FilterType         = '@filter_type'
				NotFilter          = 'not_filter'
				NotFilterType      = '@not_filter_type'
				ShowOwnSpid        = '@show_own_spid'
				ShowSystemSpids    = '@show_system_spids'
				ShowSleepingSpids  = '@show_sleeping_spids'
				GetFullInnerText   = '@get_full_inner_text'
				GetPlans           = '@get_plans'
				GetOuterCommand    = '@get_outer_command'
				GetTransactionInfo = '@get_transaction_info'
				GetTaskInfo        = '@get_task_info'
				GetLocks           = '@get_locks '
				GetAverageTime     = '@get_avg_time'
				GetAdditonalInfo   = '@get_additional_info'
				FindBlockLeaders   = '@find_block_leaders'
				DeltaInterval      = '@delta_interval'
				OutputColumnList   = '@output_column_list'
				SortOrder          = '@sort_order'
				FormatOutput       = '@format_output '
				DestinationTable   = '@destination_table '
				ReturnSchema       = '@return_schema'
				Schema             = '@schema'
				Help               = '@help'
			}

			Write-Message -Level Verbose -Message "Collecting sp_whoisactive data from server: $instance"

			try {
				$sqlconnection = New-Object System.Data.SqlClient.SqlConnection
				$sqlconnection.ConnectionString = $server.ConnectionContext.ConnectionString
				$sqlconnection.Open()

				if ($Database) {
					# database is being returned as something weird. change it to string without using a method then trim.
					$Database = "$Database"
					$Database = $Database.Trim()
					$sqlconnection.ChangeDatabase($Database)
				}

				$sqlcommand = New-Object System.Data.SqlClient.SqlCommand
				$sqlcommand.CommandType = "StoredProcedure"
				$sqlcommand.CommandText = "dbo.sp_WhoIsActive"
				$sqlcommand.Connection = $sqlconnection

				foreach ($param in $passedparams) {
					$sqlparam = $paramdictionary[$param]
					$value = $localparams[$param]

					switch ($value) {
						$true { $value = 1 }
						$false { $value = 0 }
					}

					[Void]$sqlcommand.Parameters.AddWithValue($sqlparam, $value)
				}

				$datatable = New-Object system.Data.DataSet
				$dataadapter = New-Object system.Data.SqlClient.SqlDataAdapter($sqlcommand)
				$dataadapter.fill($datatable) | Out-Null
				$datatable.Tables.Rows
			}
			catch {
				if ($_.Exception.InnerException -Like "*Could not find*") {
					Stop-Function -Message "sp_whoisactive not found, please install using Install-DbaWhoIsActive." -Continue
				}
				else {
					Stop-Function -Message "Invalid query." -Continue
				}
			}
		}
	}
	end {
		Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Show-SqlWhoIsActive -CustomMessage "Show-SqlWhoIsActive is no longer supported. Use Invoke-DbaWhoIsActive | Out-GridView for similar results."
	}
}