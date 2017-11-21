function Get-DbaAgentJobOutputFile {
    <#
		.Synopsis
			Returns the Output File for each step of one or many agent job with the Job Names provided dynamically if 
			required for one or more SQL Instances

		.DESCRIPTION
			This function returns for one or more SQL Instances the output file value for each step of one or many agent job with the Job Names 
			provided dynamically. It will not return anything if there is no Output File

		.PARAMETER SqlInstance 
			The SQL Server that you're connecting to. Or an array of SQL Servers

		.PARAMETER SQLCredential
			Credential object used to connect to the SQL Server as a different user be it Windows or SQL Server. Windows users are determiend by 
			the existence of a backslash, so if you are intending to use an alternative Windows connection instead of a SQL login, ensure it 
			contains a backslash.

		.PARAMETER Job
			The job(s) to process - this list is auto-populated from the server. If unspecified, all jobs will be processed.

		.PARAMETER ExcludeJob
			The job(s) to exclude - this list is auto-populated from the server

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.NOTES
			Tags: Agent, Job
			Author: Rob Sewell (https://sqldbawithabeard.com)
			Editor: niphlod
			
			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.EXAMPLE
			Get-DbaAgentJobOutputFile -SqlInstance SERVERNAME -Job 'The Agent Job' 

			This will return the configured paths to the output files for each of the job step of the The Agent Job Job 
			on the SERVERNAME instance  

		.EXAMPLE
			Get-DbaAgentJobOutputFile -SqlInstance SERVERNAME 

			This will return the configured paths to the output files for each of the job step of all the Agent Jobs
			on the SERVERNAME instance   

		.EXAMPLE
			Get-DbaAgentJobOutputFile -SqlInstance SERVERNAME,SERVERNAME2 -Job 'The Agent Job'

			This will return the configured paths to the output files for each of the job step of the The Agent Job Job 
			on the SERVERNAME instance and SERVERNAME2

		.EXAMPLE
			$Servers = 'SERVER','SERVER\INSTANCE1'
			Get-DbaAgentJobOutputFile -SqlInstance $Servers -Job 'The Agent Job' -OpenFile 

			This will return the configured paths to the output files for each of the job step of the The Agent Job Job 
			on the SERVER instance and the SERVER\INSTANCE1 and open the files if they are available

		.EXAMPLE 
			Get-DbaAgentJobOutputFile -SqlInstance SERVERNAME  | Out-GridView

			This will return the configured paths to the output files for each of the job step of all the Agent Jobs
			on the SERVERNAME instance and Pipe them to Out-GridView

		.EXAMPLE 
			(Get-DbaAgentJobOutputFile -SqlInstance SERVERNAME | ogv -PassThru).FileName | Invoke-Item

			This will return the configured paths to the output files for each of the job step of all the Agent Jobs
			on the SERVERNAME instance and Pipe them to Out-GridView and enable you to choose the output
			file and open it
		
		.EXAMPLE 
			Get-DbaAgentJobOutputFile -SqlInstance SERVERNAME -Verbose

			This will return the configured paths to the output files for each of the job step of all the Agent Jobs
			on the SERVERNAME instance and also show the job steps without an output file
	#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = 'The SQL Server Instance',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            Position = 0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [Parameter(Mandatory = $false, HelpMessage = 'SQL Credential',
            ValueFromPipelineByPropertyName = $true,
            ValueFromRemainingArguments = $false,
            Position = 1)]
        [PSCredential]$SqlCredential,
        [object[]]$Job,
        [object[]]$ExcludeJob,
        [switch][Alias('Silent')]$EnableException
    )

    process {
        foreach ($instance in $sqlinstance) {
            Write-Message -Message "Attempting to connect to $instance" -Level Verbose
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            }
            catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            $jobs = $Server.JobServer.Jobs
            if ($Job) {
                $jobs = $jobs | Where-Object Name -In $Job
            }
            if ($ExcludeJob) {
                $jobs = $jobs | Where-Object Name -NotIn $ExcludeJob
            }
            foreach ($j in $Jobs) {
                foreach ($Step in $j.JobSteps) {
                    if ($Step.OutputFileName) {
                        [pscustomobject]@{
                            ComputerName         = $server.NetName
                            InstanceName         = $server.ServiceName
                            SqlInstance          = $server.DomainInstanceName
                            Job                  = $j.Name
                            JobStep              = $Step.Name
                            OutputFileName       = $Step.OutputFileName
                            RemoteOutputFileName = Join-AdminUNC $Server.NetName $Step.OutputFileName
                            StepId               = $Step.Id
                        } | Select-DefaultView -ExcludeProperty StepId
                    }
                    else {
                        Write-Message -Level Verbose -Message "$step for $j has no output file"
                    }
                }
            }
        }
    }
}