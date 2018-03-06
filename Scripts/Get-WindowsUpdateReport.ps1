<#
	.SYNOPSIS
		Windows Update Report
		
	.DESCRIPTION
		Windows Update Report

	.EXAMPLE
		.
	
	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 08/09/2017
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
	Write-LogInfo -LogPath $sLogFile -Message "Gathering available update(s)" -TimeStamp -ToScreen
	#Récup de la liste des updates
	$AvailableUpdates = Get-WUList
	if ($AvailableUpdates) {
		Write-LogInfo -LogPath $sLogFile -Message "Found $(@($AvailableUpdates).count) update(s)" -TimeStamp -ToScreen
		$AvailableUpdates | ConvertTo-Json | Out-File $BASEFIC\MAJ_$ComputerName.json
	} else {
		Write-LogInfo -LogPath $sLogFile -Message "No update available" -TimeStamp -ToScreen
	}
} catch {
	$errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Failed gather updates : $errorMsg" -TimeStamp -ToScreen
}

Stop-Log -LogPath $sLogFile