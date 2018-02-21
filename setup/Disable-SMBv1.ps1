<#
	.SYNOPSIS
		Disable SMBv1
		
	.DESCRIPTION
        Disable SMBv1 in registry and feature

	.EXAMPLE
		.\Disable-SMBv1.ps1
	
	.NOTES
		Version			: 1.0
		Author 			: Mathieu ALLEGRET
		Date			: 20/02/2017
		Purpose/Change	: Initial script development
		
#>
[CmdletBinding()]
param()

#disable SMB1 - Server side
Write-Verbose "Disabling SMBv1 in registry - SERVER SIDE"
New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value "0" -PropertyType "Dword" -force | Out-Null
#disable SMB1 - client side
Write-Verbose "Disabling SMBv1 in registry - CLIENT SIDE"
New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10" -Name "Start" -Value "4" -PropertyType "Dword" -force | Out-Null
New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation" -Name "DependOnService" -Value "Bowser","MRxSmb20","NSI" -PropertyType "Multistring" -force | Out-Null
#Disable SMBv1 feature 
Write-Verbose "Disabling SMBv1 feature"
Disable-WindowsOptionalFeature -Online -FeatureName smb1protocol


