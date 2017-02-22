function Connect-ExchangeSession {
	$DomainName = $env:USERDNSDOMAIN
	$LDAPDomainName = $DomainName -replace '\.',',DC='
	$ExchangeServers = [ADSI]"LDAP://$DomainName/CN=Exchange Servers,OU=Microsoft Exchange Security Groups,DC=$LDAPDomainName"
	$ExchangeServer = Get-Random $($ExchangeServers.member | ?{$_ -notlike "*install*"})
	$ExchangeServer = ($ExchangeServer -split ",")[0]
	$ExchangeServer = $ExchangeServer.remove(0,3)
	$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/powershell
	Import-PSSession $session -DisableNameChecking | Out-Null
	Write-Host "Connected on Exchange via server : $ExchangeServer" -foregroundcolor yellow
}
if (!(Get-Alias nsmx -ErrorAction 0)) {New-Alias -Name nsmx -Value Connect-ExchangeSession}