function Get-IPDetails {
	[cmdletbinding()]
	param (
		[parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[string[]]$ComputerName = $env:computername
	)            

	begin {}
	
	process {
		foreach ($Computer in $ComputerName) {
			if(Test-Connection -ComputerName $Computer -Count 1 -ea 0) {
				$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $Computer | ? {$_.IPEnabled}
				foreach ($Network in $Networks) {

					$Props = [ordered]@{
						ComputerName = $Computer.ToUpper()
						IPAddress = $Network.IpAddress[0]
						SubnetMask = $Network.IPSubnet[0]
						Gateway = $Network.DefaultIPGateway
						DNSServers = $Network.DNSServerSearchOrder
						MACAddress = $Network.MACAddress
					}

					$IsDHCPEnabled = $false
					If($network.DHCPEnabled) {
						$IsDHCPEnabled = $true
					}
					$Props.Add("IsDHCPEnabled",$IsDHCPEnabled)

					New-Object -TypeName PSObject -Property $Props
				}
			}
		}
	}

end {}

}