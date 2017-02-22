#requires -version 2
function Export-iDracLicense {
<#
    .SYNOPSIS
        Export iDRAC Entreprise Licence
        
    .DESCRIPTION
        Export iDRAC Entreprise Licence
    
    .PARAMETER ExportPath
        Dossier d'export pour le fichier de licence
        
    .INPUTS
        None
        
    .OUTPUTS
        Fichier XML, par defaut dans C:\temp\
        
    .NOTES
        Version: 1.0
        Author: ALLEGRET Mathieu
        Creation Date: <Date>
        Purpose/Change: Initial script development

    .EXAMPLE
		Export-iDracLicense -ExportPath c:\temp\
        Export la licence iDrac dans le repertoire C:\temp, dans un fichier XML qui contient le nom du serveur, le serial, etc..
#>

#---------------------------------------------------------[Parameters]--------------------------------------------------------
[CmdletBinding()] 
param (
    [string]$ExportPath = "C:\Temp"
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#-----------------------------------------------------------[Functions]------------------------------------------------------------


#-----------------------------------------------------------[Execution]------------------------------------------------------------

$computername = $env:computername
if (-not (Test-Path $ExportPath)) {
	New-Item -Path $ExportPath -ItemType directory | Out-Null
}
$fqdd = racadm license view | Select-String "Entitlement ID"
$fqdd = (($fqdd.Line).split("=")[1]).Substring(1)
$dracver = racadm license view | Select-String "Device Description"
$dracver = (($dracver.line).split("=")[1]).Substring(1)
$serial = (Get-WmiObject -Class win32_bios).SerialNumber
$file = $ExportPath + $serial + "_" + $fqdd + "_" + $computername + ".xml"
racadm license export -f $file -e $fqdd

}