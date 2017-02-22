function Quit-ExchangePSSession {
Get-PSSession | ?{$_.ConfigurationName -eq "Microsoft.Exchange"} | Remove-PSSession
}
if (!(Get-Alias rmmx -ErrorAction 0)) {New-Alias -Name rmmx -Value Quit-ExchangePSSession}