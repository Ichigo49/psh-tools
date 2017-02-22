#reload.ps1
# Copy profile files to PowerShell user profile folder and restart PowerShell
# to reflect changes. Try to start from .lnk in the Start Menu or
# fallback to cmd.exe.
# We try the .lnk first because it can have environmental data attached
# to it like fonts, colors, etc.
function LaunchConsole {
	[System.Reflection.Assembly]::LoadWithPartialName("System.Diagnostics")
	#1) Get .lnk to PowerShell
	# Locale's Start Menu name?...
	$SM = [System.Environment+SpecialFolder]::StartMenu
	$CurrentUserStartMenuPath = $([System.Environment]::GetFolderPath($SM))
	$StartMenuName = Split-Path $CurrentUserStartMenuPath -Leaf                                 
	# Common Start Menu path?...
	$allUsersPath = $env:ALLUSERSPROFILE
	$AllUsersStartMenuPath = Join-Path $allUsersPath "Microsoft\Windows\${StartMenuName}"
	$PSLnkPath = @(Get-ChildItem $AllUsersStartMenuPath, $CurrentUserStartMenuPath -Recurse -Include "Windows PowerShell.lnk")
	# 2) Restart...
	# Is PowerShell available in PATH?
	if ( Get-Command "powershell.exe" -ErrorAction SilentlyContinue ) {
		if ($PSLnkPath) {
			<#
			$pi = New-Object "System.Diagnostics.ProcessStartInfo"
			$pi.FileName = $PSLnkPath[0]
			$pi.UseShellExecute = $true

			# See "powershell -help" for info on -Command
			$pi.Arguments = "-NoExit -Command Set-Location $PWD"
			#>
			Start-Process $PSLnkPath[0] -ArgumentList "-NoExit -Command Set-Location $PWD"
		}
		else { 
			# See "powershell -help" for info on -Command
			cmd.exe /c start powershell.exe -Command { Set-Location $PWD } -NoExit
		}
	}
	else {
		Write-Host -ForegroundColor RED "Powershell not available in PATH."
	}
	# Let's clean up after ourselves...
	Stop-Process -Id $PID
}