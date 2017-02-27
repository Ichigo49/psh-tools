function Get-DfsrBacklogStatus {
    <#
    .SYNOPSIS
        Retrieves the count of pending file updates between two DFS Replication partners.
    .DESCRIPTION
        The Get-DfsrBacklogStatus cmdlet retrieves a count of pending updates between two computers that participate in Distributed File System (DFS) Replication.

        Updates can be new, modified, or deleted files and folders.  Any files or folders listed in the DFS Replication backlog have not yet replicated from the source computer to the destination computer. This is not necessarily an indication of problems. A backlog indicates latency, and a backlog may be expected in your environment, depending on configuration, rate of change, network, and other factors.
    .PARAMETER ComputerName
        Specifies the name of the sending computer. A source computer is also called an outbound or upstream computer.
    .PARAMETER FolderName
        Specifies an array of names of replicated folders. If you do not specify this parameter, the cmdlet queries for all participating replicated folders. You can specify multiple folders, separated by commas.
    .EXAMPLE
        Get-DfsrBacklogStatus -ComputerName 'MyServer'
        Retrieves all configured replicated folders and their inbound backlog from each partner.
    .EXAMPLE
        Get-DfsrBacklogStatus -ComputerName 'MyServer' -FolderName 'Folder01'
        Retrieves the replicated folder 'Folder01' and its inbound backlog from each partner.
    .LINK
        https://github.com/twillin912/ServerManagementTools
    .NOTES
        Author: Trent Willingham
        Check out my other projects on GitHub https://github.com/twillin912
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWMICmdlet", "", Scope="Function", Target="*")]
    Param
    (
        [Parameter()]
        [string[]] $ComputerName = "localhost",

        [Parameter()]
        [string[]] $FolderName
    )

    Begin {
        $Output = @()
    }

    Process {
        foreach ( $Computer in $ComputerName ) {
            if ( ! ( Test-Connection -ComputerName $Computer -Count 1 -Quiet ) ) {
                Write-Error -Message "Cannot connect to '$Computer' because it is offline."
                continue
            }

            try {
                $DfsrConnInfo = Get-CimInstance -ComputerName $Computer -Namespace 'root\MicrosoftDFS' -ClassName 'DfsrConnectionInfo' -ErrorAction Stop
                $DfsrFolderInfo = Get-CimInstance -ComputerName $Computer -Namespace 'root\MicrosoftDFS' -ClassName 'DfsrReplicatedFolderInfo' -ErrorAction Stop
            }
            catch {
                Write-Warning -Message "Cannot bind to CIM instance on $Computer, failing back to WMI."
                $WmiFailback = $true
                $DfsrConnInfo = Get-WmiObject -ComputerName $Computer -Namespace 'root\MicrosoftDFS' -Class 'DfsrConnectionInfo'
                $DfsrFolderInfo = Get-WmiObject -ComputerName $Computer -Namespace 'root\MicrosoftDFS' -Class 'DfsrReplicatedFolderInfo'
            }
            if ( -not ( $DfsrConnInfo -and $DfsrFolderInfo ) ) {
                Write-Error -Message "Cannot bind to DfsrReplicated classes."
            }

            if ( $FolderName ) {
                $DfsrFolderInfo = $DfsrFolderInfo | Where-Object { $PSItem.ReplicatedFolderName -in $FolderName }
            }

            foreach ( $Folder in $DfsrFolderInfo ) {

                $FolderValues = @{
                    'FolderName'    = $Folder.ReplicatedFolderName
                    'GroupName'     = $Folder.ReplicationGroupName
                    'State'         = $Folder.State
                }

                if ( $WmiFailback ) {
                    $VersionVector = (Invoke-WmiMethod -InputObject $Folder -Name 'GetVersionVector').VersionVector
                } else {
                    $VersionVector = (Invoke-CimMethod -InputObject $Folder -MethodName 'GetVersionVector').VersionVector
                }


                $InboundPartner = $DfsrConnInfo | Where-Object { $PSItem.ReplicationGroupGUID -eq $Folder.ReplicationGroupGUID -and $PSItem.Inbound -eq $true }
                foreach ( $Partner in $InboundPartner ) {
                    try {
                        $ParterFolderInfo = Get-CimInstance -ComputerName $Partner.PartnerName -Namespace 'root\MicrosoftDFS' -ClassName 'DfsrReplicatedFolderInfo' -ErrorAction Stop
                        $PartnerFolder = $ParterFolderInfo | Where-Object { $PSItem.ReplicatedFolderGuid -eq $Folder.ReplicatedFolderGuid }
                        $Backlog = Invoke-CimMethod -InputObject $PartnerFolder -MethodName 'GetOutboundBacklogFileCount' -Arguments @{ VersionVector = $VersionVector }
                    }
                    catch {
                        Write-Warning -Message "Cannot bind to CIM instance on $($Partner.PartnerName), failing back to WMI."
                        $ParterFolderInfo = Get-WmiObject -ComputerName $Partner.PartnerName -Namespace 'root\MicrosoftDFS' -Class 'DfsrReplicatedFolderInfo'
                        $PartnerFolder = $ParterFolderInfo | Where-Object { $PSItem.ReplicatedFolderGuid -eq $Folder.ReplicatedFolderGuid }
                        $Backlog = Invoke-WmiMethod -InputObject $PartnerFolder -Name 'GetOutboundBacklogFileCount' -ArgumentList $VersionVector
                    }
                    finally {
                        $OutputValues = $FolderValues.Clone()
                        $OutputValues.Add('PartnerName',$Partner.PartnerName)
                        $OutputValues.Add('Backlog',$Backlog.BacklogFileCount)
                        $OutputObject = New-Object -TypeName PSObject -Property $OutputValues
                        $OutputObject.PSObject.TypeNames.Insert(0,'ServerManagementTools.DFS.BacklogStatus')
                        $Output += $OutputObject
                    }
                } #foreach Partner
            } #foreach Folder
        } #foreach Computer
        Write-Output -InputObject $Output
    } #Process
}
