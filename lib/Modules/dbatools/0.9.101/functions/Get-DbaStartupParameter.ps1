Function Get-DbaStartupParameter {
<#
    .SYNOPSIS
        Displays values for a detailed list of SQL Server Startup Parameters.
    
    .DESCRIPTION
        Displays values for a detailed list of SQL Server Startup Parameters including Master Data Path, Master Log path, Error Log, Trace Flags, Parameter String and much more.
        
        This command relies on remote Windows Server (SQL WMI/WinRm) access. You can pass alternative Windows credentials by using the -Credential parameter.
        
        See https://msdn.microsoft.com/en-us/library/ms190737.aspx for more information.
    
    .PARAMETER SqlInstance
        The SQL Server that you're connecting to.
    
    .PARAMETER Credential
        Credential object used to connect to the Windows Server as a different Windows user.
    
    .PARAMETER Simple
        Shows a simplified output including only Server, Master Data Path, Master Log path, ErrorLog, TraceFlags and ParameterString
    
    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
        
    .EXAMPLE
        Get-DbaStartupParameter -SqlInstance sql2014
        
        Logs into SQL WMI as the current user then displays the values for numerous startup parameters.
    
    .EXAMPLE
        $wincred = Get-Credential ad\sqladmin
        Get-DbaStartupParameter -SqlInstance sql2014 -Credential $wincred -Simple
        
        Logs in to WMI using the ad\sqladmin credential and gathers simplified information about the SQL Server Startup Parameters.
    
    .NOTES
        Tags: WSMan, SQLWMI, Memory
        dbatools PowerShell module (https://dbatools.io)
        Copyright (C) 2016 Chrissy LeMaire
        License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
    
    .LINK
        https://dbatools.io/Get-DbaStartupParameter
#>    
    [CmdletBinding()]
    param ([parameter(ValueFromPipeline, Mandatory = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]
        $SqlInstance,
        
        [Alias("SqlCredential")]
        [PSCredential]
        $Credential,
        
        [switch]
        $Simple,
        
        [switch]
        [Alias('Silent')]$EnableException
    )
    
    process {
        foreach ($instance in $SqlInstance) {
            try {
                $computerName = $instance.ComputerName
                $instanceName = $instance.InstanceName
                $ogInstance = $instance.FullSmoName
                
                $computerName = (Resolve-DbaNetworkName -ComputerName $computerName).FullComputerName
                
                Write-Message -Level Verbose -message "Attempting to connect to $computerName"
                
                if ($instanceName.Length -eq 0) { $instanceName = "MSSQLSERVER" }
                
                $displayname = "SQL Server ($instanceName)"
                
                $Scriptblock = {
                    $computerName = $args[0]
                    $displayname = $args[1]
                    
                    $wmisvc = $wmi.Services | Where-Object DisplayName -eq $displayname
                    
                    $params = $wmisvc.StartupParameters -split ';'
                    
                    $masterdata = $params | Where-Object { $_.StartsWith('-d') }
                    $masterlog = $params | Where-Object { $_.StartsWith('-l') }
                    $errorlog = $params | Where-Object { $_.StartsWith('-e') }
                    $traceflags = $params | Where-Object { $_.StartsWith('-T') }
                    
                    $debugflag = $params | Where-Object { $_.StartsWith('-t') }
                    
					<#
					if ($debugflag.length -ne 0) {
						Write-Message -Level Warning "$instance is using the lowercase -t trace flag. This is for internal debugging only. Please ensure this was intentional."
					}
					#>
                    
                    if ($traceflags.length -eq 0) {
                        $traceflags = "None"
                    }
                    else {
                        $traceflags = $traceflags.substring(2)
                    }
                    
                    if ($Simple -eq $true) {
                        [PSCustomObject]@{
                            ComputerName = $computerName
                            InstanceName = $instanceName
                            SqlInstance = $ogInstance
                            MasterData = $masterdata.TrimStart('-d')
                            MasterLog = $masterlog.TrimStart('-l')
                            ErrorLog = $errorlog.TrimStart('-e')
                            TraceFlags = $traceflags -join ','
                            ParameterString = $wmisvc.StartupParameters
                        }
                    }
                    else {
                        # From https://msdn.microsoft.com/en-us/library/ms190737.aspx
                        
                        $commandpromptparm = $params | Where-Object { $_ -eq '-c' }
                        $minimalstartparm = $params | Where-Object { $_ -eq '-f' }
                        $memorytoreserve = $params | Where-Object { $_.StartsWith('-g') }
                        $noeventlogsparm = $params | Where-Object { $_ -eq '-n' }
                        $instancestartparm = $params | Where-Object { $_ -eq '-s' }
                        $disablemonitoringparm = $params | Where-Object { $_ -eq '-x' }
                        $increasedextentsparm = $params | Where-Object { $_ -ceq '-E' }
                        
                        $minimalstart = $noeventlogs = $instancestart = $disablemonitoring = $false
                        $increasedextents = $commandprompt = $singleuser = $false
                        
                        if ($commandpromptparm -ne $null) { $commandprompt = $true }
                        if ($minimalstartparm -ne $null) { $minimalstart = $true }
                        if ($memorytoreserve -eq $null) { $memorytoreserve = 0 }
                        if ($noeventlogsparm -ne $null) { $noeventlogs = $true }
                        if ($instancestartparm -ne $null) { $instancestart = $true }
                        if ($disablemonitoringparm -ne $null) { $disablemonitoring = $true }
                        if ($increasedextentsparm -ne $null) { $increasedextents = $true }
                        
                        $singleuserparm = $params | Where-Object { $_.StartsWith('-m') }
                        
                        if ($singleuserparm.length -ne 0) {
                            $singleuser = $true
                            $singleuserdetails = $singleuserparm.TrimStart('-m')
                            # It's possible the person specified an application name
                            # if not, just say that single user is $true
                            #	if ($singleuserdetails.length -ne 0)
                            #	{
                            #		$singleuser = $singleuserdetails
                            #	}
                        }
                        
                        [PSCustomObject]@{
                            ComputerName = $computerName
                            InstanceName = $instanceName
                            SqlInstance = $ogInstance
                            MasterData = $masterdata.TrimStart('-d')
                            MasterLog = $masterlog.TrimStart('-l')
                            ErrorLog = $errorlog.TrimStart('-e')
                            TraceFlags = $traceflags -join ','
                            CommandPromptStart = $commandprompt
                            MinimalStart = $minimalstart
                            MemoryToReserve = $memorytoreserve
                            SingleUser = $singleuser
                            SingleUserName = $singleuserdetails
                            NoLoggingToWinEvents = $noeventlogs
                            StartAsNamedInstance = $instancestart
                            DisableMonitoring = $disablemonitoring
                            IncreasedExtents = $increasedextents
                            ParameterString = $wmisvc.StartupParameters
                        }
                    }
                }
                
                # This command is in the internal function
                # It's sorta like Invoke-Command. 
                if ($credential) {
                    Invoke-ManagedComputerCommand -Server $computerName -Credential $credential -ScriptBlock $Scriptblock -ArgumentList $computerName, $displayname
                }
                else {
                    Invoke-ManagedComputerCommand -Server $computerName -ScriptBlock $Scriptblock -ArgumentList $computerName, $displayname
                }
            }
            catch {
                Stop-Function -Message "$instance failed." -ErrorRecord $_ -Continue -Target $instance
            }
        }
    }
}
