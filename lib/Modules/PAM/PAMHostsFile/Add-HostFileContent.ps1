function Add-HostFileContent {
 [CmdletBinding()]
 param (
  [parameter(Mandatory=$true)]
  [ValidatePattern("\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b")]
  [string]$IPAddress,
  
  [parameter(Mandatory=$true)]
  [string]$computer
 )
 $file = Join-Path -Path $($env:windir) -ChildPath "system32\drivers\etc\hosts"
 if (-not (Test-Path -Path $file)){
   Throw "Hosts file not found"
 }
 $data = Get-Content -Path $file 
 $data += "$IPAddress  $computer"
 Set-Content -Value $data -Path $file -Force -Encoding ASCII 
 
<# 
.SYNOPSIS
Adds an IPv4 entry to the hosts file

.DESCRIPTION
Adds an entry to the hosts file using a computer name and 
IPv4 address as parameters. No checking is performed to 
test if an entry for that machine already exists.

.PARAMETER  Computer
A string representing a computer name

.PARAMETER  IPAddress
A string storing an IPv4 Address

.EXAMPLE
add-hostfilecontent -IPAddress 10.10.54.115 -computer W08R2SQL12

Adds a IPv4 record for system W08R2SQL12

.INPUTS
Parameters 

.OUTPUTS
None

.NOTES
Use add-IPv6hostfilecontent for IPV6 addresses

#>
 
}