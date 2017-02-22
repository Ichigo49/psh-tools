Function Get-RecentFile {
	[cmdletbinding()]
	Param(
		[Parameter(Position=0)]
		#make sure path exists and it belongs to the FileSystem provider
		[ValidateScript({
			if ((Test-Path -Path $_) -AND ((Resolve-Path -Path $_).Provider.Name -eq "FileSystem")) {
				$True
			}
			else {
				Throw "Verify path exists and is a FileSystem path."
			}
		})]
		[string]$Path = ".",
		[ValidateScript({$_ -ge 0})]
		[int]$Days = 1,
		[ValidateNotNullorEmpty()]
		[DateTime]$Since = (Get-Date).AddDays(-$Days).Date,
		[int]$Newest,
		[ValidateNotNullorEmpty()]
		[string]$Filter = "*",
		[switch]$Recurse
	)

	Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"

	#get a full path path for verbose messages
	$Path = Resolve-Path -Path $Path

	Write-Verbose -Message "Getting files [$filter] from $path since $($Since.ToShortDateString())"

	#sort last
	if ($Recurse) {
		$files = Get-ChildItem -path $Path -filter $Filter -File -Recurse | where {$_.LastWriteTime -ge $Since} | Sort LastWriteTime 
	}
	else {
		$files = Get-ChildItem -path $Path -filter $Filter -File | where {$_.LastWriteTime -ge $Since} | Sort LastWriteTime 
	}

	if ($Newest) {
		Write-Verbose -message "Getting $newest newest files"
		$files | Select-Object -last $Newest
	} 
	else {
		$files
	}
	Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
} #end function
 
#define an optional alias
Set-Alias -Name grf -Value Get-RecentFile