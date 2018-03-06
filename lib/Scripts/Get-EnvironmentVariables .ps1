function Get-EnvironmentVariables {
	param
	(
		[System.EnvironmentVariableTarget]
		[Parameter(Mandatory)]	
		$Target	
	)
	if ($Target) {
		[Environment]::GetEnvironmentVariables($Target)
	} else {
		[Environment]::GetEnvironmentVariables()
	}
	
}