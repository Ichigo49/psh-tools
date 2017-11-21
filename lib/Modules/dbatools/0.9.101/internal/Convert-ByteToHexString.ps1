function Convert-ByteToHexString {
<#
	.SYNOPSIS
	Converts byte object into hex string
	
	.DESCRIPTION
	Converts byte object ([byte[]]@(1,100,23,54)) into the hex string (e.g. '0x01641736')
	Used when working with SMO logins and their byte parameters: sids and hashed passwords
		
	.PARAMETER InputObject
	Input byte[] object (e.g. [byte[]]@(18,52))
	
	.NOTES
	Tags: Login, Internal
	Author: Kirill Kravtsov (@nvarscar)
	dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
	Copyright (C) 2016 Chrissy LeMaire
	License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

	.EXAMPLE
	Convert-ByteToHexString ([byte[]]@(1,100,23,54))
	
	Returns hex string '0x01641736'
	
	.EXAMPLE
	Convert-ByteToHexString 18,52
	
	Returns hex string '0x1234'
#>
	Param ([byte[]]$InputObject)
	$outString = "0x"; $InputObject | ForEach-Object { $outString += ("{0:X}" -f $_).PadLeft(2, "0") }
	Return $outString
}