function Show-BalloonTip {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Mandatory=$true)]
		[String]$Text,

		[Parameter(Mandatory=$true)]
		[String]$Title,

		[ValidateSet('None', 'Info', 'Warning', 'Error')]
		[String]$Icon = 'Info',

		[int]$Timeout = 10000
	)
	Set-StrictMode -off
	Add-Type -AssemblyName System.Windows.Forms

	if ($script:balloon -eq $null) {
		$script:balloon = New-Object System.Windows.Forms.NotifyIcon
	}

	$path                    = Get-Process -id $pid | Select-Object -ExpandProperty Path
	$balloon.Icon            = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
	$balloon.BalloonTipIcon  = $Icon
	$balloon.BalloonTipText  = $Text
	$balloon.BalloonTipTitle = $Title
	$balloon.Visible         = $true

	$balloon.ShowBalloonTip($Timeout)
} 