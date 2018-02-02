<#
	.SYSNOPSIS
		Install Windows Update
		
	.DESCRIPTION
		Install Windows Update

	.EXAMPLE
		.
	
	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 09/01/2018
		Purpose/Change	: Initial script development
		
#>
param()

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

#Import des variables exploit, modules & fonctions necessaire
. $ScriptDir\GlobalVar.ps1
Import-Module PSWindowsUpdate

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $BASELOG -ChildPath $sLogName

Start-Log -LogPath $BASELOG -LogName $sLogName -ScriptVersion $sScriptVersion

try {
	Write-LogInfo -LogPath $sLogFile -Message "Installing Updates" -TimeStamp -ToScreen
    	#List, download and install Updates but do not reboot server
	Get-WUInstall -AcceptAll -IgnoreReboot | Out-File -FilePath $sLogFile -Encoding utf8 -Append

} catch {
	$errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Failed install update : $errorMsg" -TimeStamp -ToScreen
}

Stop-Log -LogPath $sLogFile