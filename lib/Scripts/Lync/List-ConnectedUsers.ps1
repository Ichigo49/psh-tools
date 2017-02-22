<# 
	.Synopsis 
	   
	.DESCRIPTION 
	   
	.NOTES 
	   
	.PARAMETER Message 
	   Message is the content that you wish to add to the log file.  
	.PARAMETER Path 
	   The path to the log file to which you would like to write. By default the function will  
	   create the path and file if it does not exist.  

	.EXAMPLE
		.\toto.ps1
#>

[CmdletBinding()] 
Param 
( 
	[Parameter(Mandatory=$true,Position=1)] 
	[ValidateNotNullOrEmpty()] 
	[Alias("lp")] 
	[string]$LYNCPOOL, 
	
	[Parameter(Mandatory=$true,Position=2)] 
	[ValidateNotNullOrEmpty()] 
	[Alias("lp")] 
	[string]$FileName = ".\Lync_Users_Connected.txt"

)

$ErrorActionPreference = 'SilentlyContinue'
Import-Module ActiveDirectory
Set-AdServerSettings -ViewEntireForest $true

if (Test-Path $FileName) {
	Remove-Item $FileName
}

.\Get-CsConnections.ps1 -PoolFqdn $LYNCPOOL -IncludeUsers  | Out-File $FileName -encoding UTF8
