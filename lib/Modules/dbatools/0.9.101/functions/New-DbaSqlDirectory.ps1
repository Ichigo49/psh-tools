Function New-DbaSqlDirectory {
	<#
.SYNOPSIS
Creates new path as specified by the path variable

.DESCRIPTION
Uses master.dbo.xp_create_subdir to create the path
Returns $true if the path can be created, $false otherwise

.PARAMETER SqlInstance
The SQL Server you want to run the test on.

.PARAMETER Path
The Path to tests. Can be a file or directory.

.PARAMETER SqlCredential
Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. To use:

$scred = Get-Credential, then pass $scred object to the -SqlCredential parameter.

Windows Authentication will be used if SqlCredential is not specified. SQL Server does not accept Windows
credentials being passed as credentials. To connect as a different Windows user, run PowerShell as that user.


.NOTES
Tags: 
Author: Chrissy LeMaire (@cl), netnerds.net
Requires: Admin access to server (not SQL Services),
Remoting must be enabled and accessible if $SqlInstance is not local

dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

.LINK
https://dbatools.io/New-DbaSqlDirectory

.EXAMPLE
New-DbaSqlDirectory -SqlInstance sqlcluster -Path L:\MSAS12.MSSQLSERVER\OLAP

If the SQL Server instance sqlcluster can create the path L:\MSAS12.MSSQLSERVER\OLAP it will do and return $true, if not it will return $false. 

.EXAMPLE
$credential = Get-Credential
New-DbaSqlDirectory -SqlInstance sqlcluster -SqlCredential $credential -Path L:\MSAS12.MSSQLSERVER\OLAP

If the SQL Server instance sqlcluster can create the path L:\MSAS12.MSSQLSERVER\OLAP it will do and return $true, if not it will return $false. Uses a SqlCredential to connect
#>
	[CmdletBinding()]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstanceParameter]$SqlInstance,
		[Parameter(Mandatory = $true)]
		[string]$Path,
		[PSCredential]$SqlCredential
	)
	
	$server = Connect-SqlInstance -SqlInstance $SqlInstance -SqlCredential $SqlCredential
	
	$Path = $Path.Replace("'", "''")
	
	$exists = Test-DbaSqlPath -SqlInstance $sqlinstance -SqlCredential $SqlCredential -Path $Path
	
	if ($exists) {
		Write-Warning "$Path already exists"
		return
	}
	
	$sql = "EXEC master.dbo.xp_create_subdir'$path'"
	Write-Debug $sql
	
	try {
		$query = $server.Query($sql)
		$Created = $true
	}
	catch {
		$Created = $false
	}
	
	[pscustomobject]@{
		Server  = $SqlInstance
		Path    = $Path
		Created = $Created
	}   
}
