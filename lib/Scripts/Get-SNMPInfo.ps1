function Get-SNMPInfos {
	$RegSNMP = "HKLM:\SYSTEM\CurrentControlSet\services\SNMP"
	$RegSNMPParam = Join-Path $RegSNMP "Parameters"
	$RegSNMPTrap = Join-Path $RegSNMPParam "TrapConfiguration"
	$RegSNMPAgent = Join-Path $RegSNMPParam "RFC1156Agent"
	$RegSNMPPermit = Join-Path $RegSNMPParam "PermittedManagers"
	$RegSNMPCommunities = Join-Path $RegSNMPParam "ValidCommunities"
	Write-Host "`nChecking SNMP Parameters`n" -fore yellow
	if (Test-Path $RegSNMPParam) {
		#Onglet Trap/Interruptions
		$Community = (Get-ChildItem $RegSNMPTrap -EA 0).Name
		Write-Host "-------------- Trap Tab --------------`n" -fore black
		Write-Host "Community `t: " -NoNewLine
		if ($Community) {
			$CommunityName = ($Community.Split("\"))[($Community.Split("\")).count-1]
			Write-Host $CommunityName -fore green
			Write-Host "Destinations `t: " -NoNewLine
			$TrapDestinationsValues = (Get-ChildItem $RegSNMPTrap).GetValueNames()
			$TrapsDest = @()
			foreach ($item in $TrapDestinationsValues) {
				$TrapsDest += (Get-ItemProperty -Path $RegSNMPTrap\$CommunityName).$item
			}
			Write-Host "$($TrapsDest -join " | ")`n" -fore green
		} else {
			Write-Host "none" -fore red
		}
		#Onglet Security
		#ValidCommunities
		Write-Host "------------ Security Tab ------------`n" -fore black
		Write-Host "  -------- Valid Communities -------`n" -fore black
		$ValidCommunities = (Get-Item $RegSNMPCommunities).GetValueNames()
		Write-Host "Name `t: " -NoNewLine
		foreach ($ValidCommunity in $ValidCommunities) {
			$ComType = (Get-ItemProperty $RegSNMPCommunities).$ValidCommunity
			switch ($ComType){
					"1" { $ComMode = "None"; break }
					"2" { $ComMode = "NOTIFIER"; break }
					"4" { $ComMode = "READ ONLY"; break }
					"8" { $ComMode = "READ WRITE"; break }
					"16" { $ComMode = "READ CREATE" ; break }                
					default { $ComMode = "Unknown"; break }
			}
			Write-Host $ValidCommunity -fore green
			Write-Host "Mode `t: " -NoNewLine
			Write-Host $ComMode -fore green
		}
		#PermittedManagers
		Write-Host "`n  ------- Permitted Managers -------`n" -fore black
		$PermittedManagers = (Get-Item $RegSNMPPermit).GetValueNames()
		Write-Host "Address : " -NoNewLine
		$PermittedAddr = @()
		foreach ($Permitted in $PermittedManagers) {
			$PermittedAddr += (Get-ItemProperty $RegSNMPPermit).$Permitted
		}
		Write-Host "$($PermittedAddr -join " | ")`n" -fore green
		#Onglet Agent

		<# 
		Write-Host "Agent Tab :"
		$sysServices = (Get-ItemProperty $RegSNMPAgent).ysServices
		if ($sysServices -eq 1){
			#si = 79, tout est cochee
			#superieur a 16, alors applications est cochee
			#sinon :
			#superieur a 14, alors bout en bout - internet - liaison cochee
			#Sinon si supérieur a 
			#
			#
			#
		}
		Write-Host "`t"
		#>
	}
	else {
		Write-Host "SNMP not installed !" -fore red
	}
}