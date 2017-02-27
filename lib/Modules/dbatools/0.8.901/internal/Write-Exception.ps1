﻿Function Write-Exception
{
<#
.SYNOPSIS
Internal function. Writes exception to disk (my docs\dbatools-exceptions.txt) for later analysis.
#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[object]$e
	)
	
	$docs = [Environment]::GetFolderPath("mydocuments")
	$errorlog = "$docs\dbatools-exceptions.txt"
	$message = $e.Exception
	$infocation = $e.InvocationInfo
	
	$position = $infocation.PositionMessage
	$scriptname = $infocation.ScriptName
	if ($e.Exception.InnerException -ne $null) { $messsage = $e.Exception.InnerException }
	
	$message = $message.ToString()
	
	Add-Content $errorlog $(Get-Date)
	Add-Content $errorlog $scriptname
	Add-Content $errorlog $position
	Add-Content $errorlog $message
	Write-Warning "See error log $(Resolve-Path $errorlog) for more details."
}
