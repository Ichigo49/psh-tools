# Created by Noah Coad on 8/12/09
# Provides easy access to common tools

function tmpedit {
	$input | out-file c:\temp\tmp.txt
	edit c:\temp\tmp.txt
}
function explore {
	start explorer "/e,$input$args"
}

function FixCRLF ($file) {
	[System.IO.File]::WriteAllText($file, [System.IO.File]::ReadAllText($file).Replace("`r", "").Replace("`n", "`r`n"))
}

