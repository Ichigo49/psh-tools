<#
  .SYNOPSIS
     Creation du profile PowerShell pour l'utilisateur courant
  
  .DESCRIPTION
    Mise en place du profile powershell

  .NOTES
    Version:        1.0
    Author:         Mathieu ALLEGRET
    Creation Date:  05/10/2015
    Purpose/Change: Initial function development

  .EXAMPLE
   .\SetupPshProfile.ps1 
#>
#Write-Host "Creation Profile PowerShell ..." -ForegroundColor yellow -NoNewLine
$fullPathIncFileName = $MyInvocation.MyCommand.Definition
$PoshDir = ((Get-Item $fullPathIncFileName).DirectoryName).Replace("\setup","")
$PoshScript = "$PoshDir\posh-envt.ps1"
if (!(Test-Path $profile)) {
  New-Item $profile -ItemType file -force | Out-Null
}
Set-Content -Value ". $PoshScript" -Path $profile
Write-Host "Done !" -ForegroundColor green