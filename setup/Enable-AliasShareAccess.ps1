<#
	.SYNOPSIS
		Allow other machines to access share using aliases
		
	.DESCRIPTION
        Allow other machines to access share using aliases,
        Reboot is needed

	.EXAMPLE
		.\Enable-AliasShareAccess.ps1
	
	.NOTES
		Version			: 1.0
		Author 			: Mathieu ALLEGRET
		Date			: 20/02/2017
		Purpose/Change	: Initial script development
		
#>
[CmdletBinding()]
param([String]$Aliases)

$RegKey = "HKLM:\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters"
#Allow other machines to access share using aliases
Write-Verbose "Setting DisableStrictNameChecking value to '1'"
Set-ItemProperty -Path $RegKey -Name DisableStrictNameChecking -Value 1 -PropertyType "Dword" -force | Out-Null

if ($null -ne $Aliases) {
    Write-Verbose "Setting OptionalNames value to '$Aliases'"
    #Allow File Server to access shares locally using aliases
    Set-ItemProperty -Path $RegKey -Name OptionalNames -Value $Aliases -PropertyType "MultiString" -force | Out-Null
}