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
Import-Module ReportHTML

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $BASELOG -ChildPath $sLogName
$ReportFile = "${env:computername}_WinUpdateReport_$DateDuLog.html"

Start-Log -LogPath $BASELOG -LogName $sLogName -ScriptVersion $sScriptVersion

try {
	Write-LogInfo -LogPath $sLogFile -Message "Gathering available update(s)" -TimeStamp -ToScreen
	#Récup de la liste des updates
	$AvailableUpdates = Get-WUList
	if ($AvailableUpdates) {
		Write-LogInfo -LogPath $sLogFile -Message "Found $(@($AvailableUpdates).count) update(s)" -TimeStamp -ToScreen
		$OurLogos = Get-HTMLLogos 
		$Base64GFILogo = $OurLogos.GFI_logo
		$Alternate = $OurLogos.Alternate
		$Report = @()
		$Report += Get-HTMLOpenPage -TitleText "Windows Update Report - $env:COMPUTERNAME" -LeftLogoString $Base64GFILogo -RightLogoString $Alternate
			$Report += Get-HTMLContentOpen -HeaderText "Updates available"
				$Report += Get-HTMLContentDataTable -ArrayOfObjects ($AvailableUpdates | Select-Object KB,Title,Size,@{Name="MoreInfoUrls";Expression={$_.MoreInfoUrls -join ";"}},RebootRequired) 
			$Report += Get-HTMLContentClose
		$Report += Get-HTMLClosePage
		Save-HTMLReport -ReportPath $BASEFIC -ReportName $ReportFile -ReportContent $Report -ShowReport
		Send-MailMessage -To 'mathieu.allegret@gfi.fr' -From 'noreply@gfi.fr' -SMTPServer  -BodyAsHtml -body ($Report | Out-String) -Subject "Windows Updates Status" -Attachments (Join-Path -Path $BASEFIC -ChildPath $ReportFile)
	} else {
		Write-LogInfo -LogPath $sLogFile -Message "No update available" -TimeStamp -ToScreen
	}
} catch {
	$errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Failed gather updates : $errorMsg" -TimeStamp -ToScreen
}

Stop-Log -LogPath $sLogFile