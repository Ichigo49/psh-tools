function get-licensestatus {
	param (
		[parameter(ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true)]
		[string]$computername="$env:COMPUTERNAME"
	)
	
	$lstat = DATA {
ConvertFrom-StringData -StringData @'
0 = Unlicensed
1 = Licensed
2 = OOB Grace
3 = OOT Grace
4 = Non-Genuine Grace
5 = Notification
6 = Extended Grace
'@
	}

	Get-WmiObject SoftwareLicensingProduct -ComputerName $computername |
	where {$_.PartialProductKey} |
	select Name, ApplicationId,
	@{N="LicenseStatus"; E={$lstat["$($_.LicenseStatus)"]} }
}