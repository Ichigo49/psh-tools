function listps { 
	Get-ChildItem -Recurse -Path "${psdir}\autoload" -Include "*.ps1" | ForEach-Object{$_.FullName} 
}

function editps {
	Get-ChildItem -Recurse -Path "${psdir}\autoload" -Include "${args}${input}.ps1" | edit 
}

function exploreps {
	explore $psdir
}

function loadps {
	$scripts = Get-ChildItem -Recurse -Path "${psdir}\autoload" -Include "${args}${input}.ps1" | ForEach-Object{$_.FullName}
	$scripts
	$scripts | ForEach-Object{.$_}
}
