function New-ADSnapshot{
[CmdletBinding()]
param()
PROCESS{
 if ( -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") ){
   Throw "Must run PowerShell as ADMINISTRATOR to perform these actions"
 }
 
 ntdsutil "Activate Instance ntds" snapshot create quit quit
}#process

<#
.SYNOPSIS
 Creates new AD snapshot

.EXAMPLE
 new-adsnapshot
  
#>

}