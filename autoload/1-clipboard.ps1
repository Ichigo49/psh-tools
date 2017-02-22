Add-Type -AssemblyName System.Windows.Forms

function Get-Clipboard {
	[System.Windows.Forms.Clipboard]::GetText()
}

function Set-Clipboard {
	[System.Windows.Forms.Clipboard]::SetText($input + $args)
}

function ccd {
	Get-Clipboard | Set-Location
}