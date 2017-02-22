function Test-HostPort
{
        
    <#
        .Synopsis 
            Test a host for connectivity using either WMI ping or TCP port
            
        .Description
            Allows you to test a host for connectivity before further processing
            
        .Parameter Server
            Name of the Server to Process.
            
        .Parameter TCPPort
            TCP Port to connect to. (default 135)
            
        .Parameter Timeout
            Timeout for the TCP connection (default 1 sec)
            
        .Parameter Property
            Name of the Property that contains the value to test.
            
        .Example
            cat ServerFile.txt | Test-Host | Invoke-DoSomething
            Description
            -----------
            To test a list of hosts.
            
        .Example
            cat ServerFile.txt | Test-Host -tcp 80 | Invoke-DoSomething
            Description
            -----------
            To test a list of hosts against port 80.
            
        .Example
            Get-ADComputer | Test-Host -property dnsHostname | Invoke-DoSomething
            Description
            -----------
            To test the output of Get-ADComputer using the dnshostname property
            
            
        .OUTPUTS
            System.Object
            
        .INPUTS
            System.String
            
        .Link
            Test-Port
            
        NAME:      Test-Host
        AUTHOR:    YetiCentral\bshell
        Website:   www.bsonposh.com
        LASTEDIT:  02/04/2009 18:25:15
        #Requires -Version 2.0
    #>
    [Cmdletbinding()]
    Param(
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Mandatory=$True)]
        [string]$ComputerName,
        
        [Parameter()]
        [int]$TCPPort,
        
        [Parameter()]
        [int]$timeout=3000,
        
        [Parameter()]
        [string]$property
    )
    Begin 
    {
        function PingServer 
        {
            Param($MyHost)
            $ErrorActionPreference = "SilentlyContinue"
            Write-Verbose " [PingServer] :: Pinging [$MyHost]"
            try
            {
                $pingresult = Get-WmiObject win32_pingstatus -f "address='$MyHost'"
                $ResultCode = $pingresult.statuscode
                Write-Verbose " [PingServer] :: Ping returned $ResultCode"
                if($ResultCode -eq 0) {$true} else {$false}
            }
            catch
            {
                Write-Verbose " [PingServer] :: Ping Failed with Error: ${error[0]}"
                $false
            }
        }
    }
    Process 
    {
        Write-Verbose " [Test-Host] :: Begin Process"
        if($ComputerName -match "(.*)(\$)$")
        {
            $ComputerName = $ComputerName -replace "(.*)(\$)$",'$1'
        }
        Write-Verbose " [Test-Host] :: ComputerName   : $ComputerName"
        if($TCPPort)
        {
            Write-Verbose " [Test-Host] :: Timeout  : $timeout"
            Write-Verbose " [Test-Host] :: Port     : $TCPPort"
            if($property)
            {
                Write-Verbose " [Test-Host] :: Property : $Property"
                $Result = Test-Port $_.$property -tcp $TCPPort -timeout $timeout
                if($Result)
                {
                    if($_){ $_ }else{ $ComputerName }
                }
            }
            else
            {
                Write-Verbose " [Test-Host] :: Running - 'Test-Port $ComputerName -tcp $TCPPort -timeout $timeout'"
                $Result = Test-Port $ComputerName -tcp $TCPPort -timeout $timeout
                if($Result)
                {
                    if($_){ $_ }else{ $ComputerName }
                } 
            }
        }
        else
        {
            if($property)
            {
                Write-Verbose " [Test-Host] :: Property : $Property"
                try
                {
                    if(PingServer $_.$property)
                    {
                        if($_){ $_ }else{ $ComputerName }
                    } 
                }
                catch
                {
                    Write-Verbose " [Test-Host] :: $($_.$property) Failed Ping"
                }
            }
            else
            {
                Write-Verbose " [Test-Host] :: Simple Ping"
                try
                {
                    if(PingServer $ComputerName){$ComputerName}
                }
                catch
                {
                    Write-Verbose " [Test-Host] :: $ComputerName Failed Ping"
                }
            }
        }
        Write-Verbose " [Test-Host] :: End Process"
    }
}

function Test-Port
{
        
    <#
        .Synopsis 
            Test a host to see if the specified port is open.
            
        .Description
            Test a host to see if the specified port is open.
                        
        .Parameter TCPPort 
            Port to test (Default 135.)
            
        .Parameter Timeout 
            How long to wait (in milliseconds) for the TCP connection (Default 3000.)
            
        .Parameter ComputerName 
            Computer to test the port against (Default in localhost.)
            
        .Example
            Test-Port -tcp 3389
            Description
            -----------
            Returns $True if the localhost is listening on 3389
            
        .Example
            Test-Port -tcp 3389 -ComputerName MyServer1
            Description
            -----------
            Returns $True if MyServer1 is listening on 3389
                    
        .OUTPUTS
            System.Boolean
            
        .INPUTS
            System.String
            
        .Link
            Test-Host
            Wait-Port
            
        .Notes
            NAME:      Test-Port
            AUTHOR:    bsonposh
            Website:   http://www.bsonposh.com
            Version:   1
            #Requires -Version 2.0
    #>
    
    [Cmdletbinding()]
    Param(
        [Parameter()]
        [int]$TCPport = 135,
        [Parameter()]
        [int]$TimeOut = 3000,
        [Alias("dnsHostName")]
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [String]$ComputerName = $env:COMPUTERNAME
    )
    Begin 
    {
        Write-Verbose " [Test-Port] :: Start Script"
        Write-Verbose " [Test-Port] :: Setting Error state = 0"
    }
    Process 
    {
        Write-Verbose " [Test-Port] :: Creating [system.Net.Sockets.TcpClient] instance"
        $tcpclient = New-Object system.Net.Sockets.TcpClient
        
        Write-Verbose " [Test-Port] :: Calling BeginConnect($ComputerName,$TCPport,$null,$null)"
        try
        {
            $iar = $tcpclient.BeginConnect($ComputerName,$TCPport,$null,$null)
            Write-Verbose " [Test-Port] :: Waiting for timeout [$timeout]"
            $wait = $iar.AsyncWaitHandle.WaitOne($TimeOut,$false)
        }
        catch [System.Net.Sockets.SocketException]
        {
            Write-Verbose " [Test-Port] :: Exception: $($_.exception.message)"
            Write-Verbose " [Test-Port] :: End"
            return $false
        }
        catch
        {
            Write-Verbose " [Test-Port] :: General Exception"
            Write-Verbose " [Test-Port] :: End"
            return $false
        }
        if(!$wait)
        {
            $tcpclient.Close()
            Write-Verbose " [Test-Port] :: Connection Timeout"
            Write-Verbose " [Test-Port] :: End"
            return $false
        }
        else
        {
            Write-Verbose " [Test-Port] :: Closing TCP Socket"
            try
            {
                $tcpclient.EndConnect($iar) | out-Null
                $tcpclient.Close()
            }
            catch
            {
                Write-Verbose " [Test-Port] :: Unable to Close TCP Socket"
            }
            $true
        }
    }
    End 
    {
        Write-Verbose " [Test-Port] :: End Script"
    }
}

