Function Test-DbaBackupInformation {
<#
    .SYNOPSIS
        Tests a dbatools backuphistory object is correct for restoring

    .DESCRIPTION
        Normally takes in a backuphistory object from Format-DbaBackupInformation

        This is then parse to check that it's valid for restore. Tests performed include:
            Checking unbroken LSN chain
            If the target database exists and WithReplace has been provided
            If any files already exist, but owned by other databases
            Creates any new folders required
            That the backupfiles exists at the location specified, and can be seen by the Sql Instance
        
        If no errors are found then the objects for that database will me marked as Verified.

    .PARAMETER BackupHistory
        dbatools BackupHistory object. Normally this will have been process with Select- and then Format-DbaBackupInformation

    .PARAMETER SqlInstance
        The Sql Server instance that wil be performing the restore

    .PARAMETER SqlCredential
        A Sql Credential to connect to $SqlInstance

    .PARAMETER WithReplace
        By default we won't overwrite an existing database, this switch tells us you want to

    .PARAMETER Continue
        Switch to indicate a continuing restore

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
     
    .PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

    .EXAMPLE
    
        $BackupHistory | Test-DbaBackupInformation -SqlInstance MyInstance

        $PassedDbs = $BackupHistory | Where-Object {$_.IsVerified -eq $True}
        $FailedDbs = $BackupHistory | Where-Object {$_.IsVerified -ne $True}

        Pass in a BackupHistory object to be tested against MyInstance.

        Those records that pass are marked as verified. We can then use the IsVerified property to divide the failures and succeses

    .NOTES 
    Author:Stuart Moore (@napalmgram stuart-moore.com )
    DisasterRecovery, Backup, Restore
        
    Website: https://dbatools.io
    Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
    License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

    .LINK
    https://dbatools.io/Test-DbaBackupInformation

#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Low")]
    param (
    [parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [object[]]$BackupHistory,
    [Alias("ServerInstance", "SqlServer")]
    [DbaInstanceParameter]$SqlInstance,
    [PSCredential]$SqlCredential,
    [switch]$Withreplace,
    [switch]$continue,
    [switch]$EnableException
    )

    Begin{
        try {
            $RestoreInstance = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
        }
        catch {
            Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            return
        }
        $InternalHistory = @()
    }
    Process{
        ForEach ($bh in $BackupHistory){
            $InternalHistory += $bh
        }
    }
    End{
        $Databases = $InternalHistory.Database | Select-Object -Unique
        ForEach ($Database in $Databases){
            $VerificationErrors = 0
            Write-Message -Message "Testing restore for $Database" -Level Verbose
            #Test we're only restoring backups from one dataase, or hilarity will ensure
            $DbHistory = $InternalHistory | Where-Object {$_.Database -eq $Database}
            if (( $DbHistory | Select-Object -Property OriginalDatabase -unique ).count -gt 1){
                Write-Message -Message "Trying to restore $Database from multiple sources databases" -Level Warning
                $VerificationErrors++
                
            }
            #Test Db Existance on destination
            $DbCheck = Get-DbaDatabase -SqlInstance $RestoreInstance -Database $Database
            
            if ($null -ne $DbCheck -and ($WithReplace -ne $true -and $continue -ne $true)){
                Write-Message -Message "Database $Database exists and WithReplace not specified, stopping" -Level Warning
                $VerificationErrors++
            }
            
            #Test no destinations exist
            $DbFileCheck = (Get-DbaDatabaseFile -SqlInstance $RestoreInstance -Database $Database).PhysicalName
            $OtherFileCheck = (Get-DbaDatabaseFile -SqlInstance $RestoreInstance -ExcludeDatabase $Database).PhysicalName
            ForEach ($path in ($DbHistory | Select-Object -ExpandProperty filelist | Select-Object PhysicalName -Unique).physicalname){
                if(Test-DbaSqlPath -SqlInstance $RestoreInstance -Path $path){
                    if (($path -in $DBFileCheck) -and ($WithReplace -ne $True -and $Continue -ne $True)) {
                        Write-Message -Message "File $Path already exists on $SqlInstance and WithReplace not specified, cannot restore" -Level Warning
                        $VerificationErrors++
                    }
                    elseif ($path -in $OtherFileCheck){
                        Write-Message -Message "File $Path already exists on $SqlInstance and owned by another database, cannot restore" -Level Warning
                        $VerificationErrors++
                    }
                }
                else {
                    if (!(Test-DbaSqlPath -SqlInstance $RestoreInstance -Path (Split-path $path)) ){
                        $ConfirmMessage = "`n Creating Folder $(Split-Path $path) on $SqlInstance `n"                  
                        If ($Pscmdlet.ShouldProcess("$Path on $SqlInstance `n `n", $ConfirmMessage)) {
                            if (New-DbaSqlDirectory -SqlInstance $RestoreInstance -Path (Split-path $path)){
                                Write-Message -Message "Created Folder $(Split-path $path) on $SqlInstance" -Level Verbose
                            }
                            else {
                                Write-Message -Message "Failed to create $(Split-path $path) on $SqlInstance" -Level Warning
                                $VerificationErrors++
                            }
                        }
                    }
                }
            }

            #Test all backups readable
            Foreach ($path in ($DbHistory | Select-Object -ExpandProperty FullName)){
                if(!(Test-DbaSqlPath -SqlInstance $RestoreInstance -Path $path)){
                    Write-Message -Message "Backup File $path cannot be read" -Level Warning
                    $VerificationErrors++
                }
            }

            #Test for LSN chain
            if ($true -ne $Continue){   
                if (!($DbHistory | Test-DbaLsnChain)) {
                    Write-Message -Message "LSN Check failed" -Level Verbose
                    $VerificationErrors++
                }
            }
            if ($VerificationErrors -eq 0){
                Write-Message -Message "Marking $Database as verified" -Level Verbose
                $InternalHistory | Where-Object {$_.Database -eq $Database} | ForEach-Object {$_.IsVerified = $True}
            }
            else{
                Write-Message -Message "Verification errors  = $VerificationErrors - Has not Passed" -Level Verbose
            }
        }
        $InternalHistory
    }
}