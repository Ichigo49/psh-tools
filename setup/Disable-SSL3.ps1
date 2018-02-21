<#
	.SYNOPSIS
		Disable SSL 3.0
		
	.DESCRIPTION
        Disable SSL 3.0 in registry

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

#Disable SSL 3.0
Write-Verbose "Disabling SSL 3.0 in registry"
New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" -name "DisabledByDefault" -value "1" -PropertyType "Dword" -force | Out-Null
New-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" -name "Enabled" -value "0" -PropertyType "Dword" -force | Out-Null
