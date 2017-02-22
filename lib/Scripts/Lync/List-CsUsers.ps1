<# 
	.Synopsis 
	   Liste les utilisateurs activé sur Lync
	.DESCRIPTION 
	   Liste les utilisateurs activé sur Lync
	.NOTES 
	   
	.PARAMETER Disable 
		Chercher les utilisateurs non activé sur Lync

	.EXAMPLE
		.\List-CsUser.ps1
#>

[CmdletBinding()]
param (
	[switch]$disable
)

$ErrorActionPreference = 'SilentlyContinue'
Import-Module ActiveDirectory
Set-AdServerSettings -ViewEntireForest $true
$Output = @()

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

$FileName = Join-Path $ScriptDir "Lync_Users_Activated.csv"

if (Test-Path $FileName) {
  Remove-Item $FileName
}

if ($disable) {
	$Test = $False
}
else {
	$Test = $True
}

Foreach ($LyncUser in Get-CSUser -ResultSize Unlimited | where{$_.Enabled -eq $Test} | Sort-Object Name)
{
	$ADUser = Get-ADUser -Identity $LyncUser.SAMAccountName 
	$Output += New-Object PSObject -Property @{FirstName=$LyncUser.FirstName;LastName=$LyncUser.LastName;DisplayName=$LyncUser.DisplayName; DistinguishedName=$LyncUser.DistinguishedName; userPrincipalName=$ADUser.userPrincipalName;ExtensionAttribute14=$ADUser.ExtensionAttribute14;SIPAddress=$LyncUser.SIPAddress; RegistrarPool=$LyncUser.RegistrarPool;EVEnabled=$LyncUser.EnterpriseVoiceEnabled}
}

$Output | Export-CSV -Path $FileName
$Output | Format-Table ExtensionAttribute14,FirstName, LastName, DisplayName, DistinguishedName, SIPAddress, RegistrarPool, EVEnabled