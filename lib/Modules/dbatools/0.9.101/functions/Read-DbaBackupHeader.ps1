#ValidationTags#Messaging,FlowControl,Pipeline,CodeStyle#

Function Read-DbaBackupHeader {
<#
.SYNOPSIS 
Reads and displays detailed information about a SQL Server backup

.DESCRIPTION
Reads full, differential and transaction log backups. An online SQL Server is required to parse the backup files and the path specified must be relative to that SQL Server.
	
.PARAMETER SqlInstance
The SQL Server instance. 

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. 

.PARAMETER Path
Path to SQL Server backup file. This can be a full, differential or log backup file.
Accepts valid filesystem paths and URLs
	
.PARAMETER Simple
Returns fewer columns for an easy overview
	
.PARAMETER FileList
Returns detailed information about the files within the backup

.PARAMETER AzureCredential
Name of the SQL Server credential that should be used for Azure storage access	

.PARAMETER EnableException
		By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
		This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
		Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		
.NOTES
Tags: DisasterRecovery, Backup, Restore
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

.LINK
https://dbatools.io/Read-DbaBackupHeader

.EXAMPLE
Read-DbaBackupHeader -SqlInstance sql2016 -Path S:\backups\mydb\mydb.bak

Logs into sql2016 using Windows authentication and reads the local file on sql2016, S:\backups\mydb\mydb.bak.
	
If you are running this command on a workstation and connecting remotely, remember that sql2016 cannot access files on your own workstation.

.EXAMPLE
Read-DbaBackupHeader -SqlInstance sql2016 -Path \\nas\sql\backups\mydb\mydb.bak, \\nas\sql\backups\otherdb\otherdb.bak

Logs into sql2016 and reads two backup files - mydb.bak and otherdb.bak. The SQL Server service account must have rights to read this file.
	
.EXAMPLE
Read-DbaBackupHeader -SqlInstance . -Path C:\temp\myfile.bak -Simple
	
Logs into the local workstation (or computer) and shows simplified output about C:\temp\myfile.bak. The SQL Server service account must have rights to read this file.

.EXAMPLE
$backupinfo = Read-DbaBackupHeader -SqlInstance . -Path C:\temp\myfile.bak
$backupinfo.FileList
	
Displays detailed information about each of the datafiles contained in the backupset.

.EXAMPLE
Read-DbaBackupHeader -SqlInstance . -Path C:\temp\myfile.bak -FileList
	
Also returns detailed information about each of the datafiles contained in the backupset.

.EXAMPLE
"C:\temp\myfile.bak", "\backupserver\backups\myotherfile.bak" | Read-DbaBackupHeader -SqlInstance sql2016

Similar to running Read-DbaBackupHeader -SqlInstance sql2016 -Path "C:\temp\myfile.bak", "\backupserver\backups\myotherfile.bak"
	
.EXAMPLE
Get-ChildItem \\nas\sql\*.bak | Read-DbaBackupHeader -SqlInstance sql2016

Gets a list of all .bak files on the \\nas\sql share and reads the headers using the server named "sql2016". This means that the server, sql2016, must have read access to the \\nas\sql share.

.EXAMPLE
Read-DbaBackupHeader -Path https://dbatoolsaz.blob.core.windows.net/azbackups/restoretime/restoretime_201705131850.bak
 -AzureCredential AzureBackupUser

Gets the backup header information from the SQL Server backup file stored at https://dbatoolsaz.blob.core.windows.net/azbackups/restoretime/restoretime_201705131850.bak on Azure
#>
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $true)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter]
        $SqlInstance,
        
        [PsCredential]
        $SqlCredential,
        
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]
        $Path,
        
        [switch]
        $Simple,
        
        [switch]
        $FileList,
        
        [string]
        $AzureCredential,
        
        [switch]
        [Alias('Silent')]$EnableException
    )
    
    begin {
        $LoopCnt = 1
        
        try {
            $server = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            return
        }
    }
    
    process {
        if (Test-FunctionInterrupt) { return }
        $PathCount = $path.length
        Write-Message -Level Verbose -Message "$pathcount files to scan"
        foreach ($file in $path) {
            if ($null -ne $file.FullName) { $file = $file.FullName }
            Write-Progress -Id 1 -Activity Updating -Status 'Progress' -CurrentOperation "Scanning Restore headers on File $LoopCnt - $file"
            
            Write-Message -Level Verbose -Message "Scanning file $file"
            $restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
            if ($file -like 'http*') {
                $DeviceType = 'URL'
                $restore.CredentialName = $AzureCredential
            }
            else {
                $DeviceType = 'FILE'
            }
            $device = New-Object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $file, $DeviceType
            $restore.Devices.Add($device)
            if ((Test-DbaSqlPath -SqlInstance $server -Path $file) -or $DeviceType -eq 'URL') {
				<#	try
					{
						$allfiles = $restore.ReadFileList($server)
					}
					catch
					{
						$shortname = Split-Path $file -Leaf
						if (!(Test-DbaSqlPath -SqlInstance $server -Path $file))
						{
							Write-Warning "File $shortname does not exist or access denied. The SQL Server service account may not have access to the source directory."
						}
						else
						{
							Write-Warning "File list for $shortname could not be determined. This is likely due to the file not existing, the backup version being incompatible or unsupported, connectivity issues or tiemouts with the SQL Server, or the SQL Server service account does not have access to the source directory."
						}
					}
					

				}#>
                try {
                    $datatable = $restore.ReadBackupHeader($server)
                }
                catch {
                    Write-Exception $_
                    if ($DeviceType -eq 'FILE') {
                        Write-Message -Level Warning -Message "Problem with $file"
                    }
                    else {
                        Write-Message -Level Warning -Message "Cannot reach $file, check credential name and network connectivity"
                    }
                    Return
                }

                $fl = $datatable.Columns.Add("FileList", [object])
                #$datatable.rows[0].FileList = $allfiles.rows
                
                $mb = $datatable.Columns.Add("BackupSizeMB", [int])
                $mb.Expression = "BackupSize / 1024 / 1024"
                $gb = $datatable.Columns.Add("BackupSizeGB")
                $gb.Expression = "BackupSizeMB / 1024"
                
                if ($null -eq $datatable.Columns['CompressedBackupSize']) {
                    $formula = "0"
                }
                else {
                    $formula = "CompressedBackupSize / 1024 / 1024"
                }
                
                $cmb = $datatable.Columns.Add("CompressedBackupSizeMB", [int])
                $cmb.Expression = $formula
                $cgb = $datatable.Columns.Add("CompressedBackupSizeGB")
                $cgb.Expression = "CompressedBackupSizeMB / 1024"
                
                $null = $datatable.Columns.Add("SqlVersion")
                
                
                $null = $datatable.Columns.Add("BackupPath")
                #	$datatable.Columns["BackupPath"].DefaultValue = $Path
                $dbversion = $datatable.Rows[0].DatabaseVersion
                
                #	$datatable.Rows[0].SqlVersion = (Convert-DbVersionToSqlVersion $dbversion)
                $BackupSlot = 1
                ForEach ($row in $DataTable) {
                    $row.SqlVersion = (Convert-DbVersionToSqlVersion $dbversion)
                    $row.BackupPath = $file
                    try {
                        $restore.FileNumber = $BackupSlot
                        #Select-Object does a quick and dirty conversion from datatable to PS object
                        $allfiles = $restore.ReadFileList($server) | select-object *
                    }
                    catch {
                        $shortname = Split-Path $file -Leaf
                        if (!(Test-DbaSqlPath -SqlInstance $server -Path $file)) {
                            Write-Message -Level Warning -Message "File $shortname does not exist or access denied. The SQL Server service account may not have access to the source directory."
                        }
                        else {
                            Write-Message -Level Warning -Message "File list for $shortname could not be determined. This is likely due to the file not existing, the backup version being incompatible or unsupported, connectivity issues or tiemouts with the SQL Server, or the SQL Server service account does not have access to the source directory."
                        }
                        
                        #Write-Exception $_
                        #return
                    }
                    $row.FileList = $allfiles
                    $BackupSlot++
                   
                }
            }
            else {
                Write-Message -Level Warning -Message "File $shortname does not exist or access denied. The SQL Server service account may not have access to the source directory."
                return
            }
            if ($Simple) {
                $datatable | Select-Object DatabaseName, BackupFinishDate, RecoveryModel, BackupSizeMB, CompressedBackupSizeMB, DatabaseCreationDate, UserName, ServerName, SqlVersion, BackupPath
            }
            elseif ($FileList) {
                $datatable.filelist
            }
            else {
                $datatable
            }
            
            Remove-Variable DataTable -ErrorAction SilentlyContinue
        }
        $LoopCnt++
    }
}

