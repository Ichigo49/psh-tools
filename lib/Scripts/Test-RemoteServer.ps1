Function Test-RemoteServer
{
    <#
    .SYNOPSIS
        Test connectivity to a server using multiple methods.
    .DESCRIPTION
        Test the following connectivity methods to a server: RDP, ping, rpc, wsman, sccm agent,
        scom agent, and remote registry. Optionally an alternate credential can be used.
    .PARAMETER ComputerName
        Computer or IP address of machine to test
    .PARAMETER PingTest
        Perform a Ping test
    .PARAMETER RPCTest
        Perform an RPC test
    .PARAMETER RDPTest
        Perform an RDP test
    .PARAMETER RemoteRegistryTest
        Perform a remote registry test
    .PARAMETER WSManTest
        Perform a WSMan test
    .PARAMETER SCCMTest
        Check for SCCM components
    .PARAMETER SCOMTest
        Check for SCOM components
    .PARAMETER AllTests
        By default no tests are performed. This option enables all tests instead.
    .PARAMETER ReturnFullResults
        By default if only a single test is specified then the results returned are either true or false.
        If this parameter is set to true, then a single test still results in a psobject with properties for 
        each other test (but simply not set to any value).
    .PARAMETER PromptForCredential
        Set this if you want the function to prompt for alternate credentials.
    .PARAMETER Credential
        Pass an alternate credential
    .EXAMPLE
        Test-RemoteServer server1 | ft

        Description:
        ------------------
        Only does a dns lookup for server1 and returns the Domain, Hostname, and IP (as well as the tested entity of "server1")

    .EXAMPLE
        "server1","localhost" | Test-RemoteServer -PingTest | ft

        Description:
        ------------------
        Get connection information for server1 and the localhost returning either true or false for each server.

     .EXAMPLE
        Test-RemoteServer Server1 -RDPTest -PingTest | select Name,RPC,RDP | ft

        Description:
        ------------------
        Get RPC (WMI) and ping connection status only for server1 then output only the Name,RPC and RDP results as a table

    .LINK
        http://www.the-little-things.net/
    .LINK
        http://nl.linkedin.com/in/zloeber
    .NOTES
        - This is a heavily modified version of the script found here:
        http://gallery.technet.microsoft.com/scriptcenter/Powershell-Test-RemoteServer-e0cdea9a
        
        - Be aware that if the DNS lookup for the tested host returns multiple IP addresses
        all IP addresses will be tested and multiple results will be returned.
        
        - If a particular test is not performed then the associated property is returned as blank in a custom object
        
        - TrueFalseMode has no effect if multiple tests are specified when calling the function.
        
        - The RDP test is only a port test.
        
        - The RPC/WMI test fails if it does not properly authenticate. If this test does succeed
        then it also automatically updates the returned hostname and domain.
        
        - The WSman test is a simple connectivity test without authentication. 
        
        - The remote registry actually tests the remote registry service is running, thus WMI
        must test as running for the remote registry test to succeed. The same goes for the
        SCCM/SCOM tests. Coincidentally, if the RPC test fails and TrueFalseMode is not in effect
        then all tests related to wmi connectivity will be set to false.
        
        - The SCOM groups result will not work with alternate credentials (yet!)
        
        Name       : Test-RemoteServer
        Version    : 1.0.0 June 7th 2013
                           - First release
                     1.0.1 June 26th 2013
                           - Changed bool params to be switch params instead.
                     1.0.2 June 27th 2013
                           - Removed default switch parameter assignments of $false (as that is assumed)
                           - Changed parameter TrueFalseMode to be ReturnFullResults to reverse the default logic and clean up the parameters.
                           - Embedded the remote service testing function in the BEGIN block

        Author     : Zachary Loeber
        Website    : http://www.the-little-things.net
        Linkedin   : http://nl.linkedin.com/in/zloeber
        Disclaimer : This script is provided AS IS without warranty of any kind. I 
                     disclaim all implied warranties including, without limitation,
                     any implied warranties of merchantability or of fitness for a 
                     particular purpose. The entire risk arising out of the use or
                     performance of the sample scripts and documentation remains
                     with you. In no event shall I be liable for any damages 
                     whatsoever (including, without limitation, damages for loss of 
                     business profits, business interruption, loss of business 
                     information, or other pecuniary loss) arising out of the use of or 
                     inability to use the script or documentation. 

        Copyright  : I believe in sharing knowledge, so this script and its use is 
                     subject to : http://creativecommons.org/licenses/by-sa/3.0/
    #>
    [cmdletBinding()]
    param(
        [parameter( Position=0,
                    Mandatory=$true,
                    ValueFromPipeline=$true,
                    HelpMessage="Computer or IP address of machine to test")]
        [string[]]$ComputerName,
        [parameter( HelpMessage="Perform a Ping test")]
        [switch]$PingTest,
        [parameter( HelpMessage="Perform an RPC test")]
        [switch]$RPCTest,
        [parameter( HelpMessage="Perform an RDP test")]
        [switch]$RDPTest,
        [parameter( HelpMessage="Perform a remote registry test")]
        [switch]$RemoteRegistryTest,
        [parameter( HelpMessage="Perform a WSMan test")]
        [switch]$WSManTest,
        [parameter( HelpMessage="Check for SCCM components")]
        [switch]$SCCMTest,
        [parameter( HelpMessage="Check for SCOM components")]
        [switch]$SCOMTest,
        [parameter( HelpMessage="By default no tests are enabled. This option enables all tests instead.")]
        [switch]$AllTests,
        [parameter( HelpMessage="By default no tests are enabled. This option enables all tests instead.")]
        [switch]$ReturnFullResults,
        [parameter( HelpMessage="Set this if you want the function to prompt for alternate credentials.")]
        [switch]$PromptForCredential,
        [parameter( HelpMessage="Pass an alternate credential")]
        [System.Management.Automation.PSCredential]$Credential
    )
    BEGIN
    {
        #region Functions
        Function Get-RemoteService
        {
            <#
            .SYNOPSIS
                Retrieve remote service information.
            .DESCRIPTION
                Retreives remote service information with WMI and, optionally, a different credentail.
            .PARAMETER Name
                The service name to return. Accepted via pipeline.
            .PARAMETER ComputerName
                Computer with service to check
            .PARAMETER IncludeDriverServices
                Include the normally hidden kernel and file system drivers. Only applicable when calling the function
                without a service name specified.
            .PARAMETER PromptForCredential
                Set this if you want the function to prompt for alternate credentials
            .PARAMETER Credential
                Pass an alternate credential
            .NOTES
                Name       : Get-RemoteService
                Version    : 1.0.0 June 16th 2013
                                   - First release


                Author     : Zachary Loeber

                Disclaimer : This script is provided AS IS without warranty of any kind. I 
                             disclaim all implied warranties including, without limitation,
                             any implied warranties of merchantability or of fitness for a 
                             particular purpose. The entire risk arising out of the use or
                             performance of the sample scripts and documentation remains
                             with you. In no event shall I be liable for any damages 
                             whatsoever (including, without limitation, damages for loss of 
                             business profits, business interruption, loss of business 
                             information, or other pecuniary loss) arising out of the use of or 
                             inability to use the script or documentation. 

                Copyright  : I believe in sharing knowledge, so this script and its use is 
                             subject to : http://creativecommons.org/licenses/by-sa/3.0/
            .LINK
                http://www.the-little-things.net/
            .LINK
                http://nl.linkedin.com/in/zloeber
                
            .EXAMPLE
                $Cred = Get-Credential
                Get-Service | Get-RemoteService -ComputerName 'testserver1' -Credential $Cred | Measure-Object

                Description:
                ------------------
                Returns a count of all services on testserver1 with the same name as those found on the local system
                using alternate credentials.
            .EXAMPLE
                Get-RemoteService -ComputerName 'testserver1' -PromptForCredentials $true

                Description:
                ------------------
                Returns all services on testserver1 prompting for credentials (once).
            #>
            [CmdletBinding()]
            param( 
                [Parameter( Position=0,
                            ValueFromPipelineByPropertyName=$true,                    
                            ValueFromPipeline=$true,
                            HelpMessage="The service name to return." )]
                [Alias('ServiceName')]
                [string[]]$Name,
                [parameter( HelpMessage="Computer with service to check" )]
                [string]$ComputerName = $env:computername,
                [parameter( HelpMessage="Include the normally hidden driver services. Only applicable when not supplying a specific service name." )]
                [bool]$IncludeDriverServices = $false,
                [parameter( HelpMessage="Set this if you want the function to prompt for alternate credentials" )]
                [bool]$PromptForCredential = $false,
                [parameter( HelpMessage="Pass an alternate credential" )]
                [System.Management.Automation.PSCredential]$Credential
            )
            BEGIN 
            {
                if ($PromptForCredential)
                {
                    $Credential = Get-Credential
                }
            }
            PROCESS
            {
                $services = @()
                if ($Name)
                {
                    $services += $Name
                }
                $wmiparams = @{ 
                                Namespace = 'root\CIMV2'
                                Class = 'Win32_Service'
                                ComputerName = $ComputerName
                                ErrorAction = 'Stop'
                              }
                if ($Credential -ne $null)
                {
                    $wmiparams.Credential = $Credential
                }
                if ($services.count -ge 1)
                {
                    Foreach ($service in $services)
                    {
                        $wmiparams.Filter = "Name='$($service)'"
                        
                        try
                        {
                            $wmiparams.Class = 'Win32_Service'
                            $result = Get-WmiObject @wmiparams | select Name,DisplayName,PathName,Started,StartMode,State,ServiceType
                            if ($result -eq $null)
                            {
                                $wmiparams.Class = 'Win32_SystemDriver'
                                $result = Get-WmiObject @wmiparams | select Name,DisplayName,PathName,Started,StartMode,State,ServiceType
                            }
                            if ($result -ne $null)
                            {
                                $result
                            }
                        }
                        catch
                        {
                            $date = get-date -Format MM-dd-yyyy
                            $time = get-date -Format hh.mm
                            $erroroutput = "$date;$time;$ComputerName;$service;$_"
                            Write-Error $erroroutput
                        }
                    }
                }
                else
                {
                    $wmiparams.Filter = ""
                    try
                    {
                        $result = Get-WmiObject @wmiparams | select Name,DisplayName,PathName,Started,StartMode,State,ServiceType
                        if (($result -ne $null) -and ($IncludeDriverServices))
                        {
                            $wmiparams.Class = 'Win32_SystemDriver'
                            $result += Get-WmiObject @wmiparams | select Name,DisplayName,PathName,Started,StartMode,State,ServiceType
                        }
                        if ($result -ne $null)
                        {
                            $result
                        }
                    }
                    catch
                    {
                        $date = get-date -Format MM-dd-yyyy
                        $time = get-date -Format hh.mm
                        $erroroutput = "$date;$time;$ComputerName;$service;$_"
                        Write-Warning $erroroutput
                    }
                }
            }
        }
        #endregion Functions
        $total = Get-Date
        if ($PromptForCredential)
        {
            $Credential = Get-Credential
        }
        if ($AllTests)
        {
            $PingTest=$true
            $RPCTest=$true
            $RDPTest=$true
            $RemoteRegistryTest=$true
            $WSManTest=$true
            $SCCMTest=$true
            $SCOMTest=$true            
        }        
        $TestCount = ([int]$PingTest.IsPresent + 
                      [int]$RPCTest.IsPresent + 
                      [int]$RDPTest.IsPresent + 
                      [int]$RemoteRegistryTest.IsPresent + 
                      [int]$WSManTest.IsPresent +
                      [int]$SCCMTest.IsPresent +
                      [int]$SCOMTest.IsPresent)
        $ReturnBooleansOnly = (($TestCount -eq 1) -and (!$ReturnFullResults))
    }
    PROCESS
    {
        $computernames = @()
        $results = @()
        $computernames += $ComputerName
        foreach($name in $computernames)
        {
            $dt = $cdt = Get-Date
            Write-verbose "Testing: $Name"
            try
            {
                $DNSEntity = [Net.Dns]::GetHostEntry($name)
                $domain = ($DNSEntity.hostname).replace("^*.","")
                $hostname = $DNSEntity.hostname
                $ips = $DNSEntity.AddressList | %{$_.IPAddressToString}
            }
            catch
            {
               # If no dns entries exist just test the name
               $hostname = $name
               $ips = @($name)
            }
            Write-verbose "DNS:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
            foreach($ip in $ips)
            {                
                $rst = @{
                            TestedEntity = '';
                            Hostname = '';
                            IP = '';
                            Domain = '';
                            Ping = '';
                            WSMAN = '';
                            RemoteRegistry = '';
                            RPC = '';
                            RDP = '';
                            SCCMAgent = '';
                            SCCMAgentSiteCode = '';
                            SCOMAgent = '';
                            SCOMAgentGroups = '';
                        }
                $rst.TestedEntity = $name
                $rst.HostName = $hostname
                $rst.ip = $ip
                $rst.domain = $domain
                ####RDP Check (firewall may block rest so do before ping
                if ($RDPTest)
                {
                    try
                    {
                        $socket = New-Object Net.Sockets.TcpClient($name, 3389)
                        if($socket -eq $null)
                        {
                            $rst.RDP = $false
                        }
                        else
                        {
                            $rst.RDP = $true
                            $socket.close()
                        }
                    }
                    catch
                    {
                        $rst.RDP = $false
                    }
                    Write-verbose "RDP Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.RDP}
                }
               
                #########ping
                if ($PingTest)
                {
                    if(test-connection $ip -count 1 -Quiet)
                    {
                        $rst.ping = $true
                    }
                    else
                    {
                        $rst.ping = $false
                    }
                    Write-verbose "PING Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.ping}
                }
                
                ############wsman
                if ($WSManTest)
                {
                    $wsmanparams = @{
                                     ComputerName = $ip
                                    }
# Opted to comment this out for now as test-wsman is sufficent to determine that wsman is enabled
#  on a remote host. Auth can be done in so many ways with ws remoting that adding the credentials
#  may give false negatives.
#                    if ($Credential -ne $null)
#                    {
#                        $wsmanparams.Credential = $Credential
#                    }
                    try
                    {
                        Test-WSMan @wsmanparams | Out-Null
                        $rst.WSMAN = $true
                    }
                    catch
                    {
                        $rst.WSMAN = $false
                    }
                    Write-verbose "WSMAN Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.WSMAN}
                }
                
                ######### wmi/rpc
                If ($RPCTest)
                {
                    $WMIParameters = @{
                            			namespace = 'root\cimv2'
                                        Class = 'win32_ComputerSystem'                            			
                            			ComputerName = $Name
                                        ErrorAction = "Stop" 
                		              }
                    if ($Credential -ne $null)
                    {
                        $WMIParameters.Credential = $Credential
                    }
                    try
                    {
                        $wmiresult = Get-WmiObject @WMIParameters
                        $rst.rpc = $true
                        $rst.domain = $wmiresult.Domain
                        $rst.HostName = $wmiresult.Name
                    }
                    catch
                    {
                        # if rpc/wmi isn't working neither will some of the other tests
                        $rst.rpc = $false
                        $rst.RemoteRegistry = $false
                        $rst.SCCMAgent = $false
                        $rst.SCOMAgent = $false         
                    }
                    Write-verbose "RPC Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.rpc}
                }
                
                ########remote reg
                if (($rst.rpc -ne $false) -and $RemoteRegistryTest)
                {
                    $regparam = @{
                                  ComputerName = $ip 
                                  Name = 'RemoteRegistry'
                                 }
                    if ($Credential -ne $null)
                    {
                        $regparam.Credential = $Credential
                    }
                    try
                    {
 
                        $a = Get-RemoteService @regparam -ErrorAction Stop
                        #[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $ip) | Out-Null
                        $rst.RemoteRegistry = $true
                    }
                    catch
                    {
                        $rst.RemoteRegistry = $false
                    }
                    Write-verbose "Remote Registry Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.RemoteRegistry}
                }
                
                if (($rst.rpc -ne $false) -and $SCCMTest)
                {
                    try
                    {
                        $WMIParameters = @{
                                			namespace = 'root\cimv2'
                                            Class = 'win32_process'
                                            Filter = 'Name="ccmexec.exe"'
                                			ComputerName = $Name
                                            ErrorAction = "Stop" 
                    		              }
                        if ($Credential -ne $null)
                        {
                            $WMIParameters.Credential = $Credential
                        }
                        $SCCMCheck = Get-WMIObject @WMIParameters
                        $rst.SCCMAgent = $true
                        $WMIParameters = @{
                                			namespace = 'root\ccm\policy\machine'
                                            Class = 'CCM_SystemHealthClientConfig'
                                			ComputerName = $Name
                                            ErrorAction = "Stop" 
                        	              }
                        if ($Credential -ne $null)
                        {
                            $WMIParameters.Credential = $Credential
                        }
                        $rst.SCCMAgentSiteCode = (Get-WmiObject @WMIParameters).Sitecode
                    }
                    catch
                    {
                        $rst.SCCMAgent = $false
                    }
                    Write-verbose "SCCM Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.SCCMAgent}
                }
                
                if (($rst.rpc -ne $false) -and $SCOMTest)
                {
                    $WMIParameters = @{
                            			namespace = 'root\cimv2'
                                        Class = 'win32_process'
                                        Filter = 'Name="HealthService.exe"'
                            			ComputerName = $Name
                                        ErrorAction = "Stop" 
                    	              }
                    if ($Credential -ne $null)
                    {
                        $WMIParameters.Credential = $Credential
                    }
                    try
                    {
                        $SCOMCheck = get-wmiobject @WMIParameters
                        $rst.SCOMAgent = $true
                        
                        $path = "hklm:\SOFTWARE\MICROSOFT\MICROSOFT OPERATIONS MANAGER\3.0\AGENT MANAGEMENT GROUPS"
                        $basekey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $Name)
                        $agentgroups = ""
                         
                        ## Open the key
                        $key = $baseKey.OpenSubKey("SOFTWARE\MICROSOFT\MICROSOFT OPERATIONS MANAGER\3.0\AGENT MANAGEMENT GROUPS")
                         
                        ## Retrieve all of its children
                        foreach($subkeyName in $key.GetSubKeyNames())
                        {
                            ## Open the subkey
                            $subkey = $key.OpenSubKey($subkeyname)
                            $returnobject = [PsObject] $subkey
                            $returnobject | Add-Member NoteProperty PsChildName $subkeyName | Select PSChildName
                             
                            ## Output the key
                            $agentgroups += $returnObject.PsChildName + " "
                             
                            ## Close the child key
                            $subkey.Close()
                        }
                        ## Close the key and base keys
                        $key.Close()
                        $baseKey.Close()                
                        $rst.SCOMAgentGroups = $agentgroups
                    }
                    catch
                    {
                        $rst.SCOMAgent = $false
                    }
                    Write-verbose "SCOM Check:  $((New-TimeSpan $dt ($dt = get-date)).totalseconds)"
                    if ($ReturnBooleansOnly) {Return $rst.SCOMAgent}
                }
            
                # All done!
                $results += New-Object psobject -Property $rst
                Write-Verbose "Time for $($Name): $((New-TimeSpan $cdt ($dt)).totalseconds)"
                Write-Verbose "----------------------------"
            }
        }
    }
    END
    {
        Write-Verbose "Time for all: $((New-TimeSpan $total ($dt)).totalseconds)"
        Write-Verbose "----------------------------"
        return $results
    }
}