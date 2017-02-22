# Created by Noah Coad on 8/25/09
# .NET Framework shortcuts

function now {
	[DateTime]::Now
}

function ts { 
	$input | ForEach-Object{
		$_ -as [string]
	} 
}
