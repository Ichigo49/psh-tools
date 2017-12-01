<#
    .SYNOPSIS
        <Overview of script>
        
    .DESCRIPTION
        <Brief description of script>
    
    .PARAMETER <Parameter_Name>
        <Brief description of parameter input required. Repeat this attribute if required>
        
    .INPUTS
        <Inputs if any, otherwise state None>
        
    .OUTPUTS
        <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
        
    .NOTES
        Version: 1.0
        Author: <Name>
        Creation Date: <Date>
        Purpose/Change: Initial script development

    .EXAMPLE
        <Example goes here. Repeat this attribute for more than one example>
#>

#---------------------------------------------------------[Parameters]--------------------------------------------------------
<#
[CmdletBinding()] 
param (
    [string]$Param1,
    [int]$Param2
)
#>
#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Get Script Directory/Name
$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item -Path $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item -Path $fullPathIncFileName).Directory

#Dot Source required Variables/Function Libraries
. $ScriptDir\GlobalVar.ps1


#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -Format "yyyyMMdd_HHmmss"
$sLogPath = Join-Path -Path $BASELOG -ChildPath "log"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName


#-----------------------------------------------------------[Functions]------------------------------------------------------------


#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#Script Execution goes here
try {
	
	Write-LogInfo -LogPath $sLogFile -Message "" -TimeStamp -ToScreen
	
} catch {

	$errorMsg = $_.Exception.Message
	#Write error to log file, end the log (idem to Stop-Log cmdlet) and exit script /!\ beware to this parameter (ExitGracfully)
	Write-LogError -LogPath $sLogFile -Message "Failed to reboot server : $errorMsg" -TimeStamp -ToScreen -ExitGracefully
	
}
Stop-Log -LogPath $sLogFile
