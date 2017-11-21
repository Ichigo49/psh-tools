Function Get-RemoteShadowCopyInformation {
    <#
    .SYNOPSIS
       Gathers shadow copy volume information from a system.
    .DESCRIPTION
       Gathers shadow copy volume information from a system. Utilizes remote runspaces and alternate
       credentials.
    .PARAMETER ComputerName
       Specifies the target computer for data query.
    .PARAMETER ShadowCopiesAsBaseObject
        Return the ShadowCopies property as wmi base object instead of psobject.
    .PARAMETER ThrottleLimit
       Specifies the maximum number of systems to inventory simultaneously 
    .PARAMETER Timeout
       Specifies the maximum time in second command can run in background before terminating this thread.
    .PARAMETER ShowProgress
       Show progress bar information

    .EXAMPLE
       PS > (Get-RemoteShadowCopyInformation -ComputerName 'Server2' -Credential $cred).ShadowCopyVolumes

       ShadowSizeMax      : 16,384.00 PB
        VolumeCapacityUsed : 228.09
        Drive              : C:\
        ShadowCapacityUsed : 0
        DriveCapacity      : 20.00 GB
        ShadowSizeUsed     : 45.63 GB
       
       Description
       -----------
       Gathers shadow copy information from Server2 using alternate credentials and displays arguably the
       most useful information, the shadow copy volume information.

    .NOTES
       Author: Zachary Loeber
       Site: http://www.the-little-things.net/
       Requires: Powershell 2.0

       Version History
       1.0.0 - 09/15/2013
        - Initial release
       1.0.1 - 06/07/2015
        - Removed prompt for credentials
        - Minor code structure changes
        - Fixed a typo
        - added ShadowCopiesAsBaseObject switch
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage="Computer or computers to gather information from", ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('DNSHostName','PSComputerName')]
        [string[]]$ComputerName=$env:computername,
       
        [Parameter(HelpMessage='Return ShadowCopies property as wmi base object instead of psobject.')]
        [switch]$ShadowCopiesAsBaseObject,
        
        [Parameter(HelpMessage="Maximum number of concurrent threads")]
        [ValidateRange(1,65535)]
        [int32]$ThrottleLimit = 32,
 
        [Parameter(HelpMessage="Timeout before a thread stops trying to gather the information")]
        [ValidateRange(1,65535)]
        [int32]$Timeout = 120,
 
        [Parameter(HelpMessage="Display progress of function")]
        [switch]$ShowProgress,
        
        [Parameter(HelpMessage="Set this if you want to provide your own alternate credentials")]
        [System.Management.Automation.PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        # Gather possible local host names and IPs to prevent credential utilization in some cases
        Write-Verbose -Message 'Get-RemoteShadowCopyInformation: Creating local hostname list'
        $IPAddresses = [net.dns]::GetHostAddresses($env:COMPUTERNAME) | Select-Object -ExpandProperty IpAddressToString
        $HostNames = $IPAddresses | ForEach-Object {
            try {
                [net.dns]::GetHostByAddress($_)
            } catch {
                # We do not care about errors here...
            }
        } | Select-Object -ExpandProperty HostName -Unique
        $LocalHost = @('', '.', 'localhost', $env:COMPUTERNAME, '::1', '127.0.0.1') + $IPAddresses + $HostNames
 
        Write-Verbose -Message 'Get-RemoteShadowCopyInformation: Creating initial variables'
        $runspacetimers       = [HashTable]::Synchronized(@{})
        $runspaces            = New-Object -TypeName System.Collections.ArrayList
        $bgRunspaceCounter    = 0
        
        Write-Verbose -Message 'Get-RemoteShadowCopyInformation: Creating Initial Session State'
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        foreach ($ExternalVariable in ('runspacetimers', 'Credential', 'LocalHost')) {
            Write-Verbose -Message "Get-RemoteShadowCopyInformation: Adding variable $ExternalVariable to initial session state"
            $iss.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $ExternalVariable, (Get-Variable -Name $ExternalVariable -ValueOnly), ''))
        }
        
        Write-Verbose -Message 'Get-RemoteShadowCopyInformation: Creating runspace pool'
        $rp = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit, $iss, $Host)
        $rp.ApartmentState = 'STA'
        $rp.Open()
 
        # This is the actual code called for each computer
        Write-Verbose -Message 'Get-RemoteShadowCopyInformation: Defining background runspaces scriptblock'
        $ScriptBlock = {
            [CmdletBinding()]
            param (
                [Parameter(Position=0)]
                [string]$ComputerName,
                [Parameter(Position=1)]
                [int]$bgRunspaceID,
                [Parameter(Position=2)]
                [switch]$ShadowCopiesAsBaseObject
            )
            $runspacetimers.$bgRunspaceID = Get-Date
            filter ConvertTo-KMG  {
                $bytecount = $_
                switch ([math]::truncate([math]::log($bytecount,1024)))  {
                    0 {"$bytecount Bytes"}
                    1 {"{0:n2} KB" -f ($bytecount / 1kb)}
                    2 {"{0:n2} MB" -f ($bytecount / 1mb)}
                    3 {"{0:n2} GB" -f ($bytecount / 1gb)}
                    4 {"{0:n2} TB" -f ($bytecount / 1tb)}
                    default {"{0:n2} PB" -f ($bytecount / 1pb)}
                }
            }
            try {
                Write-Verbose -Message ('Get-RemoteShadowCopyInformation: Runspace {0}: Start' -f $ComputerName)
                $WMIHast = @{
                    ComputerName = $ComputerName
                    ErrorAction = 'Stop'
                }
                if (($LocalHost -notcontains $ComputerName) -and ($Credential -ne $null)) {
                    $WMIHast.Credential = $Credential
                }

                # General variables
                $PSDateTime = Get-Date
                
                #region Data Collection
                Write-Verbose -Message ('Get-RemoteShadowCopyInformation: Runspace {0}: Share session information' -f $ComputerName)

                # Modify this variable to change your default set of display properties
                $defaultProperties    = @('ComputerName','ShadowCopyVolumes','ShadowCopySettings', `
                                          'ShadowCopyProviders','ShadowCopies')

                $wmi_shadowcopyareas = Get-WmiObject @WMIHast -Class win32_shadowstorage
		        $wmi_volumeinfo =  Get-WmiObject @WMIHast -Class win32_volume
                $wmi_shadowcopyproviders = Get-WmiObject @WMIHast -Class Win32_ShadowProvider
                $wmi_shadowcopysettings = Get-WmiObject @WMIHast -Class Win32_ShadowContext
                $wmi_shadowcopies = Get-WmiObject @WMIHast -Class Win32_ShadowCopy
                $ShadowCopyVolumes = @()
                $ShadowCopyProviders = @()
                $ShadowCopySettings = @()
                $ShadowCopies = @()
                foreach ($shadow in $wmi_shadowcopyareas) {
                    foreach ($volume in $wmi_volumeinfo) {
                        if ($shadow.Volume -like "*$($volume.DeviceId.trimstart("\\?\Volume").trimend("\"))*") {
                            $ShadowCopyVolumeProperty =  @{
                                'Drive' = $volume.Name
                                'DriveCapacity' = $volume.Capacity | ConvertTo-KMG
        					    'ShadowSizeMax' = $shadow.MaxSpace  | ConvertTo-KMG
        					    'ShadowSizeUsed' = $shadow.UsedSpace  | ConvertTo-KMG
                                'ShadowCapacityUsed' = [math]::round((($shadow.UsedSpace/$shadow.MaxSpace) * 100),2)
                                'VolumeCapacityUsed' = [math]::round((($shadow.UsedSpace/$volume.Capacity) * 100),2)
                             }
                            $ShadowCopyVolumes += New-Object -TypeName PSObject -Property $ShadowCopyVolumeProperty
                        }
                    }
                }
                foreach ($scprovider in $wmi_shadowcopyproviders) {
                    $SCCopyProviderProp = @{
                        'Name' = $scprovider.Name
                        'CLSID' = $scprovider.CLSID
                        'ID' = $scprovider.ID
                        'Type' = $scprovider.Type
                        'Version' = $scprovider.Version
                        'VersionID' = $scprovider.VersionID
                    }
                    $ShadowCopyProviders += New-Object -TypeName PSObject -Property $SCCopyProviderProp
                }
                foreach ($scsetting in $wmi_shadowcopysettings) {
                    $SCSettingProperty = @{
                        'Name' = $scsetting.Name
                        'ClientAccessible' = $scsetting.ClientAccessible
                        'Differential' = $scsetting.Differential
                        'ExposedLocally' = $scsetting.ExposedLocally
                        'ExposedRemotely' = $scsetting.ExposedRemotely
                        'HardwareAssisted' = $scsetting.HardwareAssisted
                        'Imported' = $scsetting.Imported
                        'NoAutoRelease' = $scsetting.NoAutoRelease
                        'NotSurfaced' = $scsetting.NotSurfaced
                        'NoWriters' = $scsetting.NoWriters
                        'Persistent' = $scsetting.Persistent
                        'Plex' = $scsetting.Plex
                        'Transportable' = $scsetting.Transportable
                     }
                     $ShadowCopySettings += New-Object -TypeName PSObject -Property $SCSettingProperty

                }
                if ($ShadowCopiesAsBaseObject) {
                    $ShadowCopies = @($wmi_shadowcopies)
                }
                else {
                    foreach ($shadowcopy in $wmi_shadowcopies) {
                        $SCProperty = @{
                            'ID' = $shadowcopy.ID
                            'ClientAccessible' = $shadowcopy.ClientAccessible
                            'Count' = $shadowcopy.Count
                            'DeviceObject' = $shadowcopy.DeviceObject
                            'Differential' = $shadowcopy.Differential
                            'ExposedLocally' = $shadowcopy.ExposedLocally
                            'ExposedName' = $shadowcopy.ExposedName
                            'ExposedRemotely' = $shadowcopy.ExposedRemotely
                            'HardwareAssisted' = $shadowcopy.HardwareAssisted
                            'Imported' = $shadowcopy.Imported
                            'NoAutoRelease' = $shadowcopy.NoAutoRelease
                            'NotSurfaced' = $shadowcopy.NotSurfaced
                            'NoWriters' = $shadowcopy.NoWriters
                            'Persistent' = $shadowcopy.Persistent
                            'Plex' = $shadowcopy.Plex
                            'ProviderID' = $shadowcopy.ProviderID
                            'ServiceMachine' = $shadowcopy.ServiceMachine
                            'SetID' = $shadowcopy.SetID
                            'State' = $shadowcopy.State
                            'Transportable' = $shadowcopy.Transportable
                            'VolumeName' = $shadowcopy.VolumeName
                        }
                        $ShadowCopies += New-Object -TypeName PSObject -Property $SCProperty
                    }
                }
                $ResultProperty = @{
                    'PSComputerName' = $ComputerName
                    'PSDateTime' = $PSDateTime
                    'ComputerName' = $ComputerName
                    'ShadowCopyVolumes' = $ShadowCopyVolumes
                    'ShadowCopySettings' = $ShadowCopySettings
                    'ShadowCopies' = $ShadowCopies
                    'ShadowCopyProviders' = $ShadowCopyProviders
                }
                                    
                $ResultObject += New-Object -TypeName PSObject -Property $ResultProperty
                
                # Setup the default properties for output
                $ResultObject.PSObject.TypeNames.Insert(0,'My.ShadowCopy.Info')
                $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
                $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
                $ResultObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers

                Write-Output -InputObject $ResultObject
                #endregion Data Collection
            }
            catch {
                Write-Warning -Message ('Get-RemoteShadowCopyInformation: {0}: {1}' -f $ComputerName, $_.Exception.Message)
            }
            Write-Verbose -Message ('Get-RemoteShadowCopyInformation: Runspace {0}: End' -f $ComputerName)
        }
 
        Function Get-Result {
            [CmdletBinding()]
            param  (
                [switch]$Wait
            )
            do {
                $More = $false
                foreach ($runspace in $runspaces) {
                    $StartTime = $runspacetimers[$runspace.ID]
                    if ($runspace.Handle.isCompleted) {
                        Write-Verbose -Message ('Get-RemoteShadowCopyInformation: Thread done for {0}' -f $runspace.IObject)
                        $runspace.PowerShell.EndInvoke($runspace.Handle)
                        $runspace.PowerShell.Dispose()
                        $runspace.PowerShell = $null
                        $runspace.Handle = $null
                    }
                    elseif ($runspace.Handle -ne $null) {
                        $More = $true
                    }
                    if ($Timeout -and $StartTime) {
                        if ((New-TimeSpan -Start $StartTime).TotalSeconds -ge $Timeout -and $runspace.PowerShell) {
                            Write-Warning -Message ('Timeout {0}' -f $runspace.IObject)
                            $runspace.PowerShell.Dispose()
                            $runspace.PowerShell = $null
                            $runspace.Handle = $null
                        }
                    }
                }
                if ($More -and $PSBoundParameters['Wait']) {
                    Start-Sleep -Milliseconds 100
                }
                foreach ($threat in $runspaces.Clone()) {
                    if ( -not $threat.handle) {
                        Write-Verbose -Message ('Get-RemoteShadowCopyInformation: Removing {0} from runspaces' -f $threat.IObject)
                        $runspaces.Remove($threat)
                    }
                }
                if ($ShowProgress) {
                    $ProgressSplatting = @{
                        Activity = 'Get-RemoteShadowCopyInformation: Getting info'
                        Status = 'Get-RemoteShadowCopyInformation: {0} of {1} total threads done' -f ($bgRunspaceCounter - $runspaces.Count), $bgRunspaceCounter
                        PercentComplete = ($bgRunspaceCounter - $runspaces.Count) / $bgRunspaceCounter * 100
                    }
                    Write-Progress @ProgressSplatting
                }
            }
            while ($More -and $PSBoundParameters['Wait'])
        }
    }
    process {
        foreach ($Computer in $ComputerName) {
            $bgRunspaceCounter++
            $psCMD = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock)
            $null = $psCMD.AddParameter('bgRunspaceID',$bgRunspaceCounter)
            $null = $psCMD.AddParameter('ComputerName',$Computer)
            $null = $psCMD.AddParameter('ShadowCopiesAsBaseObject',$ShadowCopiesAsBaseObject)
            $null = $psCMD.AddParameter('Verbose',$VerbosePreference)
            $psCMD.RunspacePool = $rp
 
            Write-Verbose -Message ('Get-RemoteShadowCopyInformation: Starting {0}' -f $Computer)
            [void]$runspaces.Add(@{
                Handle = $psCMD.BeginInvoke()
                PowerShell = $psCMD
                IObject = $Computer
                ID = $bgRunspaceCounter
           })
           Get-Result
        }
    }
    end {
        Get-Result -Wait
        if ($ShowProgress) {
            Write-Progress -Activity 'Get-RemoteShadowCopyInformation: Getting share session information' -Status 'Done' -Completed
        }
        Write-Verbose -Message "Get-RemoteShadowCopyInformation: Closing runspace pool"
        $rp.Close()
        $rp.Dispose()
    }
}