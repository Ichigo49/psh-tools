function Get-UserSID { 
<#
.DESCRIPTION: 
	Obtenir le SID a partir d'un nom d'utilisateur (local ou domaine) et inversement

.PARAMETER User
	Nom du compte utilisateur
	
.PARAMETER SID
	SID de l'utilisateur
	
.PARAMETER domain
	Nom du domaine de l'utilisateur

.NOTES
	Version: 1.0
	Author: ALLEGRET Mathieu
	Creation Date: 12/07/2014
	Purpose/Change: Initial script development

.EXAMPLE 
	.\SYS_User-SID.ps1 -User totoro
	Obtenir le SID du compte local "totoro"
.EXAMPLE 
	.\SYS_User-SID.ps1 -User totoro -domain ghibli
	Obtenir le SID du compte "totoro" du domaine "ghibli"
.EXAMPLE 
	.\SYS_User-SID.ps1 -SID S-1-5-21-2069765483-2054585454-1267821858-67278
	Obtenir le compte (local ou domaine) a partir du SID
#>
param (
	[string]$User,
	[string]$SID,
	[string]$domain
)

 
function domSID {
$objUser = New-Object System.Security.Principal.NTAccount("$domain", "$user")
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$strSID.Value
}

function SID {
$objSID = New-Object System.Security.Principal.SecurityIdentifier ("$SID")
$objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
$objUser.Value
}

function userSID {
$objUser = New-Object System.Security.Principal.NTAccount("$user")
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$strSID.Value
}

if($User -AND $SID) {Write-Output 'Mauvaise utilisation'; Continue } 
if($domain -AND $SID) {Write-Output 'Mauvaise utilisation'; Continue } 
if($domain -AND !$user) {Write-Output 'Mauvaise utilisation'; Continue } 
if($User -AND !$SID -AND !$domain) {userSID} 
if($User -AND !$SID -AND $domain) {domSID} 
if(!$User -AND $SID -AND !$domain) {SID} 
}
