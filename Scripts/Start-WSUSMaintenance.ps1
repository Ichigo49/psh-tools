<#
	.SYNOPSIS
		Start a WSUS Database maintenance
		
	.DESCRIPTION
		Start a WSUS Database maintenance

	.EXAMPLE
		.\Start-WSUSMaintenance.ps1
		
		----------
		Execute the WSUS DB maintenance
		

	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 21/02/2018
		Purpose/Change	: Initial script development
		
#>

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

. $ScriptDir\GlobalVar.ps1
. $BASELIB\Scripts\Invoke-WSUSMaintenance.ps1

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $BASELOG -ChildPath $sLogName
$ScriptSQL = Join-Path -Path $BASEFIC -ChildPath "WsusDBMaintenance.sql"

Start-Log -LogPath $BASELOG -LogName $sLogName -ScriptVersion $sScriptVersion

try {

	Write-LogInfo -LogPath $sLogFile -Message "Starting WSUS DB Maintenance" -TimeStamp -ToScreen
	#$result = Invoke-WSUSDBMaintenance -UpdateServer serverwsus -Port 8530 -Verbose *>&1
	sqlcmd -S '\\.\pipe\MICROSOFT##WID\tsql\query' -i $ScriptSQL | Out-File -FilePath $sLogFile -Append -Encoding utf8
	#Add-Content -Path $sLogFile -Value $result
	Write-LogInfo -LogPath $sLogFile -Message "WSUS DB Maintenance finished" -TimeStamp -ToScreen
} catch {
	
    $errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Error during maintenance : $errorMsg" -TimeStamp -ToScreen -ExitGracefully
}

Stop-Log -LogPath $sLogFile