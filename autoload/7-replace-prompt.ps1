function Get-Time {
return $(get-date | foreach { $_.ToLongTimeString() } ) 
}
#Modification de l'affichage du prompt
function prompt
{
    $cwd = (get-location).Path
	$cwd = $cwd.replace($home,"~")
	[array]$cwdt=$()
	$cwdi=-1
	do {
		$cwdi = $cwd.indexofany("\",$cwdi+1)
		[array]$cwdt += $cwdi
	} until($cwdi -eq -1)
	if ($cwdt.count -gt 3) {
		$cwd = $cwd.substring(0,$cwdt[0]) + ".." + $cwd.substring($cwdt[$cwdt.count-3])
	}
	# Write the time 
    write-host "[" -noNewLine
    write-host $(Get-Time) -foreground yellow -noNewLine
    write-host "] " -noNewLine
    # Write the path
    write-host $cwd -foreground green -noNewLine
    write-host $(if ($nestedpromptlevel -ge 1) { '>>' }) -noNewLine
    return "> "
}
