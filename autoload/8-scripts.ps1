function listps { 
	gci -Recurse -Path "${psdir}\autoload" -Include "*.ps1" | %{$_.FullName} 
}

function editps {
	gci -Recurse -Path "${psdir}\autoload" -Include "${args}${input}.ps1" | edit 
}

function exploreps {
	explore $psdir
}

function loadps {
	$scripts = gci -Recurse -Path "${psdir}\autoload" -Include "${args}${input}.ps1" | %{$_.FullName}
	$scripts
	$scripts | %{.$_}
}
