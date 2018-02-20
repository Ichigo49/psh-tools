<#
	.SYNOPSIS
		WSUS new updates HTML Report
		
	.DESCRIPTION
		WSUS new updates HTML Report

	.EXAMPLE
		.
	
	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 13/02/2018
		Purpose/Change	: Initial script development
		
#>
param()

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptName = (Get-Item $fullPathIncFileName).BaseName
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

#Import des variables exploit, modules & fonctions necessaire
. $ScriptDir\GlobalVar.ps1
Import-Module PoshWSUS
Import-Module ReportHTML

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$DateDuLog = Get-Date -f "yyyyMMdd_HHmmss"
$sLogName = "${ScriptName}_$DateDuLog.log"
$sLogFile = Join-Path -Path $BASELOG -ChildPath $sLogName
$ReportFile = "WSUSReport_$DateDuLog.html"

Start-Log -LogPath $BASELOG -LogName $sLogName -ScriptVersion $sScriptVersion

$null = Connect-PSWSUSServer -WsusServer serverwsus -Port 8530

try {
	Write-LogInfo -LogPath $sLogFile -Message "Gathering available update(s) on WSUS Server" -TimeStamp -ToScreen
	#Récup de la liste des updates
	$AvailableUpdates = Get-PSWSUSUpdate | Where-Object {$_.IsApproved -eq $false -and $_.IsDeclined -eq $false}
	if ($AvailableUpdates) {
		Write-LogInfo -LogPath $sLogFile -Message "Found $(@($AvailableUpdates).count) update(s)" -TimeStamp -ToScreen
		$OurLogos = Get-HTMLLogos 
		$Base64GFILogo = $OurLogos.GFI
		$Alternate = $OurLogos.Alternate
		$Report = @()
		$Report += Get-HTMLOpenPage -TitleText "WSUS Report - Pending Approval" -LeftLogoString $Base64GFILogo -RightLogoString $Alternate
			$Report += Get-HTMLContentOpen -HeaderText "Updates en attente sur le serveur WSUS"
				$Report += Get-HTMLContentDataTable -ArrayOfObjects ($AvailableUpdates | Select-Object @{Name="KB";Expression={$_.KnowledgebaseArticles -join ";"}},Title,@{Name='Classification';Expression={$_.UpdateClassificationTitle}},@{Name="MoreInfoUrls";Expression={$_.AdditionalInformationUrls -join ";"}}) 
			$Report += Get-HTMLContentClose
		$Report += Get-HTMLClosePage
		Save-HTMLReport -ReportPath $BASEFIC -ReportName $ReportFile -ReportContent $Report -ShowReport
		Send-MailMessage -To 'mathieu.allegret@gfi.fr' -From 'no-reply@aesn.fr' -SMTPServer msvexch02p.aesn.fr -BodyAsHtml -body ($Report | Out-String) -Subject "WSUS AESN - Updates Status" -Attachments (Join-Path -Path $BASEFIC -ChildPath $ReportFile)
	} else {
		Write-LogInfo -LogPath $sLogFile -Message "No update available" -TimeStamp -ToScreen
		
	}
} catch {
	$errorMsg = $_.Exception.Message
	Write-LogError -LogPath $sLogFile -Message "Failed gather updates : $errorMsg" -TimeStamp -ToScreen
}

Stop-Log -LogPath $sLogFile