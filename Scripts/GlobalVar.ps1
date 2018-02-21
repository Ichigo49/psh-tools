<#
	.SYNOPSIS
		Positionnement de variables global pour les script d'exploit
		
	.DESCRIPTION
		Positionnement de variables global pour les script d'exploit

	.EXAMPLE
		. .\GlobalVar.ps1
		Chargement des variables global dans les scritps d'exploit
		
	.NOTES
		Version			: 1.0
		Author 			: M. ALLEGRET
		Date			: 08/09/2017
		Purpose/Change	: Initial script development
#>
 if ((Test-Path variable:\GlobalVar) -eq $False) {
	# Variables

	$VOLEXPLOIT = ($MyInvocation.MyCommand.Definition).Remove(2) # On garde la lettre du lecteur
	$BASEEXPLOIT = Join-Path $VOLEXPLOIT "exploit"
	$BASELIB = Join-Path $BASEEXPLOIT "lib"
	$BASEFIC = Join-Path $BASEEXPLOIT "fic"
	$BASEBIN = Join-Path $BASEEXPLOIT "bin"
	$BASESYSint = Join-Path $BASEBIN "Sysinternals"
	$BASELOG = Join-Path $BASEEXPLOIT "log"
	$BASEUTIL = Join-Path $BASEEXPLOIT "util"
	$BASESCRIPTS = Join-Path $BASEEXPLOIT "Scripts"
	$journal = Join-Path $BASELOG "journal.log"
	$ComputerName = $env:computername
	$env:PSModulePath = $env:PSModulePath + ";" + $BASELIB + "\Modules"

	$GlobalVar = 1    
	$OSlang = (Get-WmiObject Win32_OperatingSystem).oslanguage    
	$OSver = (Get-WmiObject Win32_OperatingSystem).version    
	$OSName = (Get-WmiObject Win32_OperatingSystem).caption    
	$OSArchi = (Get-WmiObject Win32_OperatingSystem).OSarchitecture    
	$PSver = $psversiontable.psversion.major

	Import-Module PSLogging
	
	function Pause ($Message="Press any key to continue...")
	{
		Write-Host -NoNewLine $Message
		$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		Write-Host ""
	}

	function Test-IsElevatedUser 
	{
		$IsElevatedUser = $false
		try {
			$WindowsIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
			$WindowsPrincipal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $WindowsIdentity
			$IsElevatedUser =  $WindowsPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )
		} catch {
			throw "Elevated privileges is undetermined; the error was: '{0}'." -f $_
		}
		return $IsElevatedUser
	}

	function Get-ScriptDirectory
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}

	Function Start-Countdown 
	{   
		Param(
			[Int32]$Seconds = 10,
			[string]$Message = "Pausing for $Seconds seconds..."
		)
		ForEach ($Count in (1..$Seconds))
		{   Write-Progress -Id 1 -Activity $Message -Status "Waiting for $Seconds seconds, $($Seconds - $Count) seconds left" -PercentComplete (($Count / $Seconds) * 100)
			Start-Sleep -Seconds 1
		}
		Write-Progress -Id 1 -Activity $Message -Status "Completed" -PercentComplete 100 -Completed
	}
}