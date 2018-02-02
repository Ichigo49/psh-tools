<#
	.SYSNOPSIS
		Rotations fichier de log dans \Exploit\log
		
	.DESCRIPTION
		Rotations fichier de log dans \Exploit\log

	.EXAMPLE
		
		

	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 25/01/2018
		Purpose/Change	: Initial script development
		
#>

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

. $ScriptDir\GlobalVar.ps1
. $BASELIB\Scripts\New-LogRotate.ps1
#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $BASELOG -ChildPath $sLogName

Start-Log -LogPath $BASELOG -LogName $sLogName -ScriptVersion $sScriptVersion

try {
	Write-LogInfo -LogPath $sLogFile -Message "Starting rotation of logs in $BASELOG" -TimeStamp -ToScreen
	
	New-LogRotate -LogDir $BASELOG
	
	Write-LogInfo -LogPath $sLogFile -Message "Log Rotate OK" -TimeStamp -ToScreen
} catch {
	$errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Error while rotate logs : $errorMsg" -TimeStamp -ToScreen
}

Stop-Log -LogPath $sLogFile