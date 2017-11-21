function Set-DbaAgentJob {
    <#
.SYNOPSIS 
Set-DbaAgentJob updates a job.

.DESCRIPTION
Set-DbaAgentJob updates a job in the SQL Server Agent with parameters supplied.

.PARAMETER SqlInstance
SQL Server instance. You must have sysadmin access and server version must be SQL Server version 2000 or greater.

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:
$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter. 
To connect as a different Windows user, run PowerShell as that user.

.PARAMETER Job
The name of the job. 

.PARAMETER Schedule
Schedule to attach to job. This can be more than one schedule.

.PARAMETER ScheduleId
Schedule ID to attach to job. This can be more than one schedule ID.

.PARAMETER NewName
The new name for the job. 

.PARAMETER Enabled
Enabled the job.

.PARAMETER Disabled
Disabled the job

.PARAMETER Description
The description of the job.

.PARAMETER StartStepId
The identification number of the first step to execute for the job.

.PARAMETER Category
The category of the job.

.PARAMETER OwnerLogin
The name of the login that owns the job.

.PARAMETER EventlogLevel
Specifies when to place an entry in the Microsoft Windows application log for this job.
Allowed values 0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always"
The text value van either be lowercase, uppercase or something in between as long as the text is correct.

.PARAMETER EmailLevel
Specifies when to send an e-mail upon the completion of this job.
Allowed values 0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always"
The text value van either be lowercase, uppercase or something in between as long as the text is correct.

.PARAMETER NetsendLevel
Specifies when to send a network message upon the completion of this job.
Allowed values 0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always"
The text value van either be lowercase, uppercase or something in between as long as the text is correct.

.PARAMETER PageLevel
Specifies when to send a page upon the completion of this job.
Allowed values 0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always"
The text value van either be lowercase, uppercase or something in between as long as the text is correct.

.PARAMETER EmailOperator
The e-mail name of the operator to whom the e-mail is sent when EmailLevel is reached.

.PARAMETER NetsendOperator
The name of the operator to whom the network message is sent.

.PARAMETER PageOperator
The name of the operator to whom a page is sent.

.PARAMETER DeleteLevel
Specifies when to delete the job.
Allowed values 0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always"
The text value van either be lowercase, uppercase or something in between as long as the text is correct.

.PARAMETER WhatIf
Shows what would happen if the command were to run. No actions are actually performed.

.PARAMETER Confirm
Prompts you for confirmation before executing any changing operations within the command.

.PARAMETER EnableException
		By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
		This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
		Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		
.NOTES 
Author: Sander Stad (@sqlstad, sqlstad.nl)
Tags: Agent, Job
	
Website: https://dbatools.io
Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

.LINK
https://dbatools.io/Set-DbaAgentJob

.EXAMPLE   
Set-DbaAgentJob sql1 -Job Job1 -Disabled
Changes the job to disabled

.EXAMPLE
Set-DbaAgentJob sql1 -Job Job1 -OwnerLogin user1
Changes the owner of the job

.EXAMPLE
Set-DbaAgentJob -SqlInstance sql1 -Job Job1 -EventLogLevel OnSuccess
Changes the job and sets the notification to write to the Windows Application event log on success

.EXAMPLE
Set-DbaAgentJob -SqlInstance sql1 -Job Job1 -EmailLevel OnFailure -EmailOperator dba
Changes the job and sets the notification to send an e-mail to the e-mail operator

.EXAMPLE
Set-DbaAgentJob -SqlInstance sql1 -Job Job1, Job2, Job3 -Enabled
Changes multiple jobs to enabled

.EXAMPLE
Set-DbaAgentJob -SqlInstance sql1, sql2, sql3 -Job Job1, Job2, Job3 -Enabled
Changes multiple jobs to enabled on multiple servers

.EXAMPLE   
Set-DbaAgentJob -SqlInstance sql1 -Job Job1 -Description 'Just another job' -Whatif
Doesn't Change the job but shows what would happen.

.EXAMPLE   
Set-DbaAgentJob -SqlInstance sql1, sql2, sql3 -Job 'Job One' -Description 'Job One'
Changes a job with the name "Job1" on multiple servers to have another description

.EXAMPLE   
sql1, sql2, sql3 | Set-DbaAgentJob -Job Job1 -Description 'Job One'
Changes a job with the name "Job1" on multiple servers to have another description using pipe line

#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
    param (
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,

        [Parameter(Mandatory = $false)]
        [PSCredential]$SqlCredential,
		
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object[]]$Job,

        [Parameter(Mandatory = $false)]
        [object[]]$Schedule,

        [Parameter(Mandatory = $false)]
        [int[]]$ScheduleId,
		
        [Parameter(Mandatory = $false)]
        [string]$NewName,
		
        [Parameter(Mandatory = $false)]
        [switch]$Enabled,
		
        [Parameter(Mandatory = $false)]
        [switch]$Disabled,
		
        [Parameter(Mandatory = $false)]
        [string]$Description,
		
        [Parameter(Mandatory = $false)]
        [int]$StartStepId,
		
        [Parameter(Mandatory = $false)]
        [string]$Category,
		
        [Parameter(Mandatory = $false)]
        [string]$OwnerLogin,
		
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always")]
        [object]$EventLogLevel,
		
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always")]
        [object]$EmailLevel,
		
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always")]
        [object]$NetsendLevel,
		
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always")]
        [object]$PageLevel,
		
        [Parameter(Mandatory = $false)]
        [string]$EmailOperator,
		
        [Parameter(Mandatory = $false)]
        [string]$NetsendOperator,
		
        [Parameter(Mandatory = $false)]
        [string]$PageOperator,
		
        [Parameter(Mandatory = $false)]
        [ValidateSet(0, "Never", 1, "OnSuccess", 2, "OnFailure", 3, "Always")]
        [object]$DeleteLevel,
		
        [switch][Alias('Silent')]$EnableException
    )
	
    begin {
        # Check of the event log level is of type string and set the integer value
        if (($EventLogLevel -notin 0, 1, 2, 3) -and ($EventLogLevel -ne $null)) {
            $EventLogLevel = switch ($EventLogLevel) { "Never" { 0 } "OnSuccess" { 1 } "OnFailure" { 2 } "Always" { 3 } }
        }
		
        # Check of the email level is of type string and set the integer value
        if (($EmailLevel -notin 0, 1, 2, 3) -and ($EmailLevel -ne $null)) {
            $EmailLevel = switch ($EmailLevel) { "Never" { 0 } "OnSuccess" { 1 } "OnFailure" { 2 } "Always" { 3 } }
        }
		
        # Check of the net send level is of type string and set the integer value
        if (($NetsendLevel -notin 0, 1, 2, 3) -and ($NetsendLevel -ne $null)) {
            $NetsendLevel = switch ($NetsendLevel) { "Never" { 0 } "OnSuccess" { 1 } "OnFailure" { 2 } "Always" { 3 } }
        }
		
        # Check of the page level is of type string and set the integer value
        if (($PageLevel -notin 0, 1, 2, 3) -and ($PageLevel -ne $null)) {
            $PageLevel = switch ($PageLevel) { "Never" { 0 } "OnSuccess" { 1 } "OnFailure" { 2 } "Always" { 3 } }
        }
		
        # Check of the delete level is of type string and set the integer value
        if (($DeleteLevel -notin 0, 1, 2, 3) -and ($DeleteLevel -ne $null)) {
            $DeleteLevel = switch ($DeleteLevel) { "Never" { 0 } "OnSuccess" { 1 } "OnFailure" { 2 } "Always" { 3 } }
        }
		
        # Check the e-mail operator name
        if (($EmailLevel -ge 1) -and (-not $EmailOperator)) {
            Stop-Function -Message "Please set the e-mail operator when the e-mail level parameter is set." -Target $sqlinstance
            return
        }
		
        # Check the e-mail operator name
        if (($NetsendLevel -ge 1) -and (-not $NetsendOperator)) {
            Stop-Function -Message "Please set the netsend operator when the netsend level parameter is set." -Target $sqlinstance
            return
        }
		
        # Check the e-mail operator name
        if (($PageLevel -ge 1) -and (-not $PageOperator)) {
            Stop-Function -Message "Please set the page operator when the page level parameter is set." -Target $sqlinstance
            return
        }
    }
	
    process {
		
        if (Test-FunctionInterrupt) { return }
		
        foreach ($instance in $sqlinstance) {
			
            # Try connecting to the instance
            Write-Message -Message "Attempting to connect to $instance" -Level Verbose
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }
			
            foreach ($j in $Job) {
				
                # Check if the job exists
                if ($Server.JobServer.Jobs.Name -notcontains $j) {
                    Stop-Function -Message "Job $j doesn't exists on $instance" -Target $instance
                }
                else {
                    # Get the job
                    try {
                        $currentjob = $server.JobServer.Jobs[$j]
						
                        # Refresh the object
                        $currentjob.Refresh()
                    }
                    catch {
                        Stop-Function -Message "Something went wrong retrieving the job. `n$($_.Exception.Message)" -Target $j -InnerErrorRecord $_ -Continue
                    }
					
                    #region job options
                    # Settings the options for the job
                    if ($NewName) {
                        Write-Message -Message "Setting job name to $NewName" -Level Verbose
                        $currentjob.Rename($NewName)
                    }
					
                    if ($Schedule) {
                        # Loop through each of the schedules
                        foreach ($s in $Schedule) {
                            if ($Server.JobServer.SharedSchedules.Name -contains $s) {
                                # Get the schedule ID
                                $sID = $Server.JobServer.SharedSchedules[$s].ID
							
                                # Add schedule to job
                                Write-Message -Message "Adding schedule id $sID to job" -Level Verbose
                                $currentjob.AddSharedSchedule($sID)
                            }
                            else {
                                Stop-Function -Message "Schedule $s cannot be found on instance $instance" -Target $s -Continue
                            }
						
                        }
                    }

                    if ($ScheduleId) {
                        # Loop through each of the schedules IDs
                        foreach ($sID in $ScheduleId) {
                            # Check if the schedule is 
                            if ($Server.JobServer.SharedSchedules.ID -contains $sID) {
                                # Add schedule to job
                                Write-Message -Message "Adding schedule id $sID to job" -Level Verbose
                                $currentjob.AddSharedSchedule($sID)
                                
                            }
                            else {
                                Stop-Function -Message "Schedule ID $sID cannot be found on instance $instance" -Target $sID -Continue
                            }
                        }
                    }

                    if ($Enabled) {
                        Write-Message -Message "Setting job to enabled" -Level Verbose
                        $currentjob.IsEnabled = $true
                    }
					
                    if ($Disabled) {
                        Write-Message -Message "Setting job to disabled" -Level Verbose
                        $currentjob.IsEnabled = $false
                    }
					
                    if ($Description) {
                        Write-Message -Message "Setting job description to $Description" -Level Verbose
                        $currentjob.Description = $Description
                    }
					
                    if ($StartStepId) {
                        # Get the job steps
                        $currentjobSteps = $currentjob.JobSteps
						
                        # Check if there are any job steps
                        if ($currentjobSteps.Count -ge 1) {
                            # Check if the start step id value is one of the job steps in the job
                            if ($currentjobSteps.ID -contains $StartStepId) {
                                Write-Message -Message "Setting job start step id to $StartStepId" -Level Verbose
                                $currentjob.StartStepID = $StartStepId
                            }
                            else {
                                Write-Message -Message "The step id is not present in job $j on instance $instance" -Warning
                            }
							
                        }
                        else {
                            Stop-Function -Message "There are no job steps present for job $j on instance $instance" -Target $instance -Continue
                        }
						
                    }
					
                    if ($Category) {
                        Write-Message -Message "Setting job category to $Category" -Level Verbose
                        $currentjob.Category = $Category
                    }
					
                    if ($OwnerLogin) {
                        # Check if the login name is present on the instance
                        if ($Server.Logins.Name -contains $OwnerLogin) {
                            Write-Message -Message "Setting job owner login name to $OwnerLogin" -Level Verbose
                            $currentjob.OwnerLoginName = $OwnerLogin
                        }
                        else {
                            Stop-Function -Message "The given owner log in name $OwnerLogin does not exist on instance $instance" -Target $instance -Continue
                        }
                    }
					
                    if ($EventLogLevel) {
                        Write-Message -Message "Setting job event log level to $EventlogLevel" -Level Verbose
                        $currentjob.EventLogLevel = $EventLogLevel
                    }
					
                    if ($EmailLevel) {
                        # Check if the notifiction needs to be removed
                        if ($EmailLevel -eq 0) {
                            # Remove the operator
                            $currentjob.OperatorToEmail = $null
							
                            # Remove the notification
                            $currentjob.EmailLevel = $EmailLevel
                        }
                        else {
                            # Check if either the operator e-mail parameter is set or the operator is set in the job
                            if ($EmailOperator -or $currentjob.OperatorToEmail) {
                                Write-Message -Message "Setting job e-mail level to $EmailLevel" -Level Verbose
                                $currentjob.EmailLevel = $EmailLevel
                            }
                            else {
                                Stop-Function -Message "Cannot set e-mail level $EmailLevel without a valid e-mail operator name" -Target $instance -Continue
                            }
                        }
                    }
					
                    if ($NetsendLevel) {
                        # Check if the notifiction needs to be removed
                        if ($NetsendLevel -eq 0) {
                            # Remove the operator
                            $currentjob.OperatorToNetSend = $null
							
                            # Remove the notification
                            $currentjob.NetSendLevel = $NetsendLevel
                        }
                        else {
                            # Check if either the operator netsend parameter is set or the operator is set in the job
                            if ($NetsendOperator -or $currentjob.OperatorToNetSend) {
                                Write-Message -Message "Setting job netsend level to $NetsendLevel" -Level Verbose
                                $currentjob.NetSendLevel = $NetsendLevel
                            }
                            else {
                                Stop-Function -Message "Cannot set netsend level $NetsendLevel without a valid netsend operator name" -Target $instance -Continue
                            }
                        }
                    }
					
                    if ($PageLevel) {
                        # Check if the notifiction needs to be removed
                        if ($PageLevel -eq 0) {
                            # Remove the operator
                            $currentjob.OperatorToPage = $null
							
                            # Remove the notification
                            $currentjob.PageLevel = $PageLevel
                        }
                        else {
                            # Check if either the operator pager parameter is set or the operator is set in the job
                            if ($PageOperator -or $currentjob.OperatorToPage) {
                                Write-Message -Message "Setting job pager level to $PageLevel" -Level Verbose
                                $currentjob.PageLevel = $PageLevel
                            }
                            else {
                                Stop-Function -Message "Cannot set page level $PageLevel without a valid netsend operator name" -Target $instance -Continue
                            }
                        }
                    }
					
                    # Check the current setting of the job's email level
                    if ($EmailOperator) {
                        # Check if the operator name is present
                        if ($Server.JobServer.Operators.Name -contains $EmailOperator) {
                            Write-Message -Message "Setting job e-mail operator to $EmailOperator" -Level Verbose
                            $currentjob.OperatorToEmail = $EmailOperator
                        }
                        else {
                            Stop-Function -Message "The e-mail operator name $EmailOperator does not exist on instance $instance. Exiting.." -Target $j -Continue
                        }
                    }
					
                    if ($NetsendOperator) {
                        # Check if the operator name is present
                        if ($Server.JobServer.Operators.Name -contains $NetsendOperator) {
                            Write-Message -Message "Setting job netsend operator to $NetsendOperator" -Level Verbose
                            $currentjob.OperatorToNetSend = $NetsendOperator
                        }
                        else {
                            Stop-Function -Message "The netsend operator name $NetsendOperator does not exist on instance $instance. Exiting.." -Target $j -Continue
                        }
                    }
					
                    if ($PageOperator) {
                        # Check if the operator name is present
                        if ($Server.JobServer.Operators.Name -contains $PageOperator) {
                            Write-Message -Message "Setting job pager operator to $PageOperator" -Level Verbose
                            $currentjob.OperatorToPage = $PageOperator
                        }
                        else {
                            Stop-Function -Message "The page operator name $PageOperator does not exist on instance $instance. Exiting.." -Target $instance -Continue
                        }
                    }
					
                    if ($DeleteLevel) {
                        Write-Message -Message "Setting job delete level to $DeleteLevel" -Level Verbose
                        $currentjob.DeleteLevel = $DeleteLevel
                    }
                    #endregion job options
					
                    # Execute 
                    if ($PSCmdlet.ShouldProcess($SqlInstance, "Changing the job $j")) {
                        try {
                            Write-Message -Message ("Changing the job") -Level Verbose
							
                            # Change the job
                            $currentjob.Alter()
                        }
                        catch {
                            Stop-Function -Message "Something went wrong changing the job. `n$($_.Exception.Message)" -Target $instance -Continue
                        }
                        Get-DbaAgentJob -SqlInstance $server | Where-Object Name -eq $currentjob.name
                    }
                }
            } # foreach object job
        } # foreach instance
    } # Process
	
    end {
		Write-Message -Message "Finished changing job(s)" -Level Verbose
    }
}
