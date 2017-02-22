function Get-HBAWin { 
param( 
[String[]]$ComputerName = $ENV:ComputerName,
[Switch]$LogOffline 
) 
 
$ComputerName | ForEach-Object { 
try {
	$Computer = $_
	
	$Params = @{
		Namespace    = 'root\WMI'
		class        = 'MSFC_FCAdapterHBAAttributes'
		ComputerName = $Computer 
		ErrorAction  = 'Stop'
		}
	
	Get-WmiObject @Params  | ForEach-Object { 
			$hash=@{ 
				ComputerName     = $_.__SERVER 
				NodeWWN          = (($_.NodeWWN) | ForEach-Object {"{0:X2}" -f $_}) -join ":" 
				Active           = $_.Active 
				DriverName       = $_.DriverName 
				DriverVersion    = $_.DriverVersion 
				FirmwareVersion  = $_.FirmwareVersion 
				Model            = $_.Model 
				ModelDescription = $_.ModelDescription 
				} 
			New-Object psobject -Property $hash 
		}#Foreach-Object(Adapter) 
}#try
catch {
	Write-Warning -Message "$Computer is offline or not supported"
	if ($LogOffline)
	{
		"$Computer is offline or not supported" >> "$home\desktop\Offline.txt"
	}
}

}#Foreach-Object(Computer) 
 
}#Get-HBAWin