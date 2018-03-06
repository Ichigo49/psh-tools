<#
	.SYNOPSIS
		Script custom, a modifier pour chaque besoin
		
	.DESCRIPTION
		Script custom, a modifier pour chaque besoin

	.EXAMPLE
		
		

	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 11/09/2017
		Purpose/Change	: Initial script development
		
#>

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

. $ScriptDir\GlobalVar.ps1

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $BASELOG -ChildPath $sLogName



Start-Log -LogPath $BASELOG -LogName $sLogName -ScriptVersion $sScriptVersion

try {


Write-LogInfo -LogPath $sLogFile -Message "" -TimeStamp -ToScreen


} catch {
	
    $errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Failed to : $errorMsg" -TimeStamp -ToScreen -ExitGracefully
}

Stop-Log -LogPath $sLogFile