if ($psversiontable.PSVersion.Major -lt 3) {

	# Historique presistant
	# Export des 1024 dernières commandes à la fermeture de la session powerhsell
	$MaximumHistoryCount = 1024
	$historyPath = Join-Path (split-path $profile) history.clixml
	# Hook powershell's exiting event & hide the registration with -supportevent (from nivot.org)
	Register-EngineEvent -SourceIdentifier powershell.exiting -SupportEvent -Action {
		Get-History -Count $MaximumHistoryCount | Export-Clixml (Join-Path (split-path $profile) history.clixml) 
	}

	# Chargement du xml si existe
	if ((Test-Path $historyPath)) {
		Import-Clixml $historyPath | ? {$count++;$true} | Add-History
		Write-Host "HISTORY : Loaded $count history item(s)`n" -Fore Green
	}

	# Alias & fonctions utiles
	function h {
		Get-History -c $MaximumHistoryCount 
	}

	function hg($arg) {
		Get-History -c $MaximumHistoryCount | out-string -stream | select-string $arg 
	}

	function hist {
		Get-History -count $MaximumHistoryCount | %{$_.commandline}
	}

	if (!(Get-Alias original_h -ErrorAction 0)) {Rename-Item Alias:\h original_h -Force}

}