  <#
  .SYNOPSIS
    Gathering Basic System Info for system Admin

  .DESCRIPTION
    Gathering Basic Info: hostname, domain name, os name, IPs, CPU/RAM, disk

  .PARAMETER ComputerName
    Par defaut, la machine qui execute le script
      
  .NOTES
    Version:        1.0
    Author:         Mathieu ALLEGRET
    Creation Date:  17/07/2015
    Purpose/Change: Initial function development

  .EXAMPLE
    .\SYS_INFO.ps1
  #>
[CmdletBinding()]
PARAM (
	[string]$ComputerName = $env:COMPUTERNAME
)

$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$ScriptDir = (Get-Item $fullPathIncFileName).Directory

. $ScriptDir\Get-RemoteDiskInformation.ps1
. $ScriptDir\Get-IPDetails.ps1

$OSInfo = Get-WmiObject -ComputerName $ComputerName -class Win32_OperatingSystem
$ComputerInfo = Get-WmiObject -ComputerName $ComputerName -class Win32_ComputerSystem
$IPInfo = Get-IPDetails
$DiskInfo = Get-RemoteDiskInformation | Where-Object {$_.Drive}
Write-host "`n****************************************************************"
Write-host "`nCarateristiques du serveur`n" -ForegroundColor yellow
Write-host "Server Name" -ForegroundColor green -NoNewline
Write-host "`t$ComputerName"
Write-host "Domain Name" -ForegroundColor green -NoNewline
Write-host "`t$($ComputerInfo.Domain)"
Write-host "OS Name" -ForegroundColor green -NoNewline
Write-host "`t`t$($OSInfo.Caption)"
if ($OSInfo.CSDVersion -ne "") {
  Write-host "OS ServicePack" -ForegroundColor green -NoNewline
  Write-host "`t$($OSInfo.CSDVersion)"
}
Write-host "CPU " -ForegroundColor green -NoNewline
Write-host "`t`t$($ComputerInfo.NumberOfProcessors) ($($ComputerInfo.NumberOfLogicalProcessors) cores)"
Write-host "RAM " -ForegroundColor green -NoNewline
Write-host "`t`t$([math]::round($ComputerInfo.TotalPhysicalMemory/1024/1024/1024)) GB"
Write-host "IP : " -ForegroundColor green -NoNewline
$IPInfo | Format-Table -autosize
Write-host "Disk : " -ForegroundColor green -NoNewline
$DiskInfo | Select-Object Drive,VolumeName,DiskSize,FreeSpace,UsedSpace,PercentUsed | Format-Table -autosize
Write-host "`n****************************************************************`n"