<#
.SYNOPSIS
	Returns current connection count for all front end servers in a given pool
	including a breakdown of connection by client, frontend server and users.

	It can also be used to return connection information on an individual user.

.DESCRIPTION
	This program will return a connection count for a given pool. The program
	can be edited to set a default pool. You will also be able to get
	information on an individual user by providing the users SamAccountName.
	As well as listing all the connected users to the default pool.

	NOTE: In order to gain remote access to each front end server's
	RTCLOCAL database where connection information is found,
	you need to open two local Windows firewall ports. Please see the installation
	info on the blog post for details.

.NOTES
  Version      	   		: 3.1 - See changelog at http://www.ehloworld.com/681
	Wish list						:
  Rights Required			: TBD
  Sched Task Required	: No
  Lync Version				: 2010 through CU7 and 2013 through CU3
  Author(s)    				: Pat Richard (pat@innervation.com) 	http://www.ehloworld.com @patrichard
  										: Tracy A. Cerise (tracy@uky.edu)
  										: Mahmoud Badran (v-mabadr@microsoft.com)
  Dedicated Post			: http://www.ehloworld.com/269
  Disclaimer   				: You running this script means you won't blame me if this breaks your stuff. This script is provided AS IS
												without warranty of any kind. I disclaim all implied warranties including, without limitation, any implied
												warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use
												or performance of the sample scripts and documentation remains with you. In no event shall I be liable for
												any damages whatsoever (including, without limitation, damages for loss of business profits, business
												interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability
												to use the script or documentation.
  Acknowledgements 		: http://blogs.technet.com/b/meacoex/archive/2011/07/19/list-connections-and-users-connected-to-lync-registrar-pool.aspx
  									  	This program's database connection information was originally taken from the "List Connections to Registrar Pools" submitted by Scott Stubberfield and Nick Smith from Microsoft to the Lync 2010 PowerShell blog  (http://blogs.technet.com/b/csps/) on June 10, 2010.
	Assumptions					: ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
  Limitations					:
  Known issues				: None yet, but I'm sure you'll find some!

.LINK
	http://www.ehloworld.com/269

.EXAMPLE
	.\Get-CsConnections.ps1

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	specified pool or server.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN]

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	Lync Server 2010 pool FQDN given with the pool parameter.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -Is2013

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	Lync Server 2013 pool FQDN given with the pool parameter.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool name]

	Description
	-----------
	Returns information on all connections on all Lync Server frontend servers
	in the pool NetBIOS name given with the pool parameter. The script will append
	the %userdnsdomain% to build the FQDN.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -SIPAddress userid@sip.domain

	Description
	-----------
	Returns all connection information for the given user including which
	frontend server connected to, how many connections and which clients
	connected with. If the environment contains only one SIP domain, only the prefix
	is required.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -FilePath c:\path\to\file\filename.csv

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	pool and in addition writes out all the raw connection information
	into the filename specified.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -IncludeUsers

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	specified pool and in addition writes out all the users connection
	information. This does NOT include system related connections.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -IncludeUsers -UserHighConnectionFlag 5

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	specified pool and in addition writes out all the users connection
	information. This does NOT include system related connections. The
	UserHighConnectionFlag integer will color	all users with that many
	(or more) connections in red. The default is 4.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -IncludeHighUsers -UserHighConnectionFlag 5

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	specified pool and in addition writes out all the users connection
	information for users with high number of connections. This does NOT
	include system related connections. The UserHighConnectionFlag integer
	will color	all users with that many (or more) connections in red.
	The default is 4.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -IncludeUsers -IncludeSystem

	Description
	-----------
	Returns information on all connections on all frontend servers in the
	specified pool and in addition writes out all the users connection
	information. This includes any system	related connections.

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -ClientVersion [version number]

	Description
	-----------
	Returns all connection information for only clients that contain the specified client version.
	Also lists the users connecting with that version (same as -IncludeUsers option).

.EXAMPLE
	.\Get-CsConnections.ps1 -PoolFqdn [pool FQDN] -ShowFullClient

	Description
	-----------
	Returns extended information for clients including mobile device OS and type.

.INPUTS
	None. You cannot pipe objects to this script.
#>
#Requires -Version 2.0

[CmdletBinding(SupportsShouldProcess = $True)]
param(
	# Defines the front end pool to query for information. Cannot be used with -Server or -SIPAddress. If not specified and there is only a single front end pool, the script will automatically determine the FQDN.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[string] $PoolFqdn,

	# Defines a specific server to query for information. Cannot be used with -PoolFqdn or -SIPAddress.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[string] $Server,

	# Defines the SIP address for a specific user to query. Cannot be used with -PoolFqdn or -Server.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[string] $SipAddress,

	# Defines the file path for the exported .csv file.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[string] $FilePath,

	# Displays connected users and their connection counts. Users with a number of connections that meets or exceeds the -UserHighConnectionFlag count are colored in red. Cannot be used with -IncludeHighUsers.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $IncludeUsers,

	# Displays connected users who meet or exceed the -UserHighConnectionFlag value. Users who are below the value are in white. Users who exceed the value are in red. Cannot be used with -IncludeUsers.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $IncludeHighUsers,

	# Includes accounts used by the system (non-users).
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $IncludeSystem,

	# Defines the value at which users are considered to have a high number of connections. Defaults to 4. Cannot exceed the number configured for MaxEndpointsPerUser in the global RegistrarConfiguration.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[ValidateRange(2,10)]
	[int] $UserHighConnectionFlag = 4,

	# Filter results to a specific version of the client. Helpful with -IncludeUsers to determine who's using a specific version of the client.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[string] $ClientVersion,

	# Displays full client version information. Useful for viewing longer mobile device info.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $ShowFullClient,

	# Queries Lync environment for total number of enabled users, and also determines percentage of total users that are currently connected.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $ShowTotal,

	# Specifies that the server the script is connecting to is running Lync Server 2013. This parameter is not required when connecting to a pool, since the script will auto detect the version.
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $Is2013,

	# Skips the check for script age
	[parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[switch] $SkipUpdateCheck
)
#region functions

function Get-Data {
	[CmdletBinding(SupportsShouldProcess = $True)]
	param (
	 [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	 [string] $SipAddress,

	 [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	 [string] $Server,

	 [parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	 [string] $ClientVersion
	)

	##############################################################################################
	# Went to using a named parameter for this function due to the
	# way Powershell does its thing with parameter passing, which
	# is NOT GOOD!  At any rate, need to call this function
	# as you would from a command line: Get-Data -sipAddr "value"
	# -server "value"
	#
	# Also, assuming a value of NULL for the SIP address of an
	# individual user, mostly to use this for finding overall
	# values, only occasionally to seek specific users.
	##############################################################################################

	if ($SipAddress) {
		[string] $whereClause = "where R.UserAtHost = '$SipAddress' "
	} else {
		if ($IncludeSystem){
			[string] $whereClause = $null
		}elseif ($ClientVersion){
			[string] $whereClause = "where upper(RE.ClientApp) like upper('%$ClientVersion%') and R.UserAtHost not like 'RtcApplication-%' "
		}else{
			[string] $whereClause = "where R.UserAtHost not like 'RtcApplication-%' "
		}
	}

	#Define SQL Connection String
	[string] $connstring = "server=$server\rtclocal;database=rtcdyn;trusted_connection=true;"

	#Define SQL Command
	[object] $command = New-Object System.Data.SqlClient.SqlCommand

	if (($PoolFqdn -and (Get-CsService -PoolFqdn $PoolFqdn -Registrar).Version -ge 6) -or $Is2013){
		# SQL query for Lync Server 2013
		$command.CommandText = "Select (cast (RE.ClientApp as varchar (100))) as ClientVersion, R.UserAtHost as UserName, RA.Fqdn `
		From rtcdyn.dbo.RegistrarEndpoint RE `
		Inner Join rtcdyn.dbo.Endpoint EP on RE.EndpointId = EP.EndpointId `
		Inner Join rtc.dbo.Resource R on R.ResourceId = RE.OwnerId `
		Inner Join rtcdyn.dbo.Registrar RA on EP.RegistrarId = RA.RegistrarId `
		$whereClause `
		Order By ClientVersion, UserName"
	}else{
		# SQL query for Lync Server 2010
		$command.CommandText = "Select (cast (RE.ClientApp as varchar (100))) as ClientVersion, R.UserAtHost as UserName, FE.Fqdn `
		From rtcdyn.dbo.RegistrarEndpoint RE `
		Inner Join rtcdyn.dbo.Endpoint EP on RE.EndpointId = EP.EndpointId `
		Inner Join rtc.dbo.Resource R on R.ResourceId = RE.OwnerId `
		Inner Join rtcdyn.dbo.FrontEnd FE on EP.RegistrarId = FE.FrontEndId `
		$whereClause `
		Order By ClientVersion, UserName"
	}

	[object] $connection = New-Object System.Data.SqlClient.SqlConnection
	$connection.ConnectionString = $connstring
	$connection.Open()

	$command.Connection = $connection

	[object] $sqladapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$sqladapter.SelectCommand = $command

	[object] $results = New-Object System.Data.Dataset
	$recordcount = $sqladapter.Fill($results)
	$connection.Close()
	return $Results.Tables[0]
} # end function Get-Data

function Set-ModuleStatus {
	[CmdletBinding(SupportsShouldProcess = $True)]
	param	(
		[parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, HelpMessage = "No module name specified!")]
		[ValidateNotNullOrEmpty()]
		[string] $name
	)
	PROCESS{
		# Executes once for each pipeline object
		# the $_ variable represents the current input object
		if (!(Get-Module -name "$name")) {
			if (Get-Module -ListAvailable | Where-Object {$_.Name -eq "$name"}) {
				Import-Module -Name "$name"
				# module was imported
				# return $true
			} else {
				# module was not available
				# return $false
			}
		} else {
			# Write-Output "$_ module already imported"
			# return $true
		}
	} # end PROCESS
} # end function Set-ModuleStatus

function Remove-ScriptVariables {
	[CmdletBinding(SupportsShouldProcess = $True)]
	param(
		[parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, HelpMessage = "No module name specified!")]
		[ValidateNotNullOrEmpty()]
		[string] $Path
	)

	$result = Get-Content $path |
	ForEach {
		if ( $_ -match '(\$.*?)\s*=') {
			$matches[1]  | ? { $_ -notlike '*.*' -and $_ -notmatch 'result' -and $_ -notmatch 'env:'}
		}
	}
	ForEach ($v in ($result | Sort-Object | Get-Unique)){
		# Write-Verbose "Removing" $v.replace("$","")
		Remove-Variable ($v.replace("$","")) -ErrorAction SilentlyContinue
	}
} # end function Remove-ScriptVariables

function Test-IsSigned {
<#
.SYNOPSIS

.DESCRIPTION

.NOTES
  Version							: 1.0 - See changelog at
	Wish list						: Better error trapping
  Rights Required			: Local administrator on server
  Sched Task Required	: No
  Lync Server Version	: N/A
  Author/Copyright		: © Pat Richard, Lync MVP - All Rights Reserved
  Email/Blog/Twitter	: pat@innervation.com 	http://www.ehloworld.com @patrichard
  Dedicated Blog Post	: http://www.ehloworld.com/1697
  Disclaimer   				: You running this script means you won't blame me if this breaks your stuff. This script is
  											provided AS IS without warranty of any kind. I disclaim all implied warranties including,
  											without limitation, any implied warranties of merchantability or of fitness for a particular
  											purpose. The entire risk arising out of the use or performance of the sample scripts and
  											documentation remains with you. In no event shall I be liable for any damages whatsoever
  											(including, without limitation, damages for loss of business profits, business interruption,
  											loss of business information, or other pecuniary loss) arising out of the use of or inability
  											to use the script or documentation.
  Assumptions					: ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
  Limitations					:
  Known issues				: None yet, but I'm sure you'll find some!
  Acknowledgements 		:

.LINK


.EXAMPLE
		PS C:\>

		Description
		-----------


.INPUTS
		None. You cannot pipe objects to this function.

.OUTPUTS
		Boolean output

#>
	[CmdletBinding(SupportsShouldProcess = $True)]
	param (
		[Parameter(ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string] $FilePath = $MyInvocation.ScriptName
	)

	BEGIN{
		# Executes once before first item in pipeline is processed
		# the $_ variable represents the current input object
	} # end BEGIN

	PROCESS{
		# Executes once for each pipeline object
		# the $_ variable represents the current input object
		if ((Get-AuthenticodeSignature -FilePath $FilePath).Status -eq "Valid"){
			<#
			if ((Get-ExecutionPolicy) -ne "AllSigned"){
				Write-Warning "You could use an ExecutionPolicy of `"AllSigned`" when using this script. AllSigned is a higher level of security. For more information, see http://technet.microsoft.com/en-us/library/ee176961.aspx"
			}
			#>
		}
	} # end PROCESS

	END{
		# Executes once after last pipeline object is processed
		# the $_ variable represents the current input object
	} # end END
} # end function Test-IsSigned

function Test-ScriptUpdates {
<#
.SYNOPSIS
	Checks the CreationTime parameter on the script itself. If it's over 30 days, it will prompt the user & optionally take them to the changelog for that script.

.DESCRIPTION
	Checks the CreationTime parameter on the script itself. If it's over 30 days, it will prompt the user & optionally take them to the changelog for that script.

.NOTES
  Version							: 1.0 - See changelog at
	Wish list						: Better error trapping
  Rights Required			: Local administrator on server
  										: If script is not signed, ExecutionPolicy of RemoteSigned (recommended)
  											or Unrestricted (not recommended)
  										: If script is signed, ExecutionPolicy of AllSigned (recommended, RemoteSigned,
  											or Unrestricted (not recommended)
  Sched Task Required	: No
  Lync Server Version	: N/A
  Exchange Version    : N/A
  Author/Copyright		: © Pat Richard, Lync MVP - All Rights Reserved
  Email/Blog/Twitter	: pat@innervation.com 	http://www.ehloworld.com @patrichard
  Dedicated Blog Post	:
  Disclaimer   				: You running this script means you won't blame me if this breaks your stuff. This script is
  											provided AS IS without warranty of any kind. I disclaim all implied warranties including,
  											without limitation, any implied warranties of merchantability or of fitness for a particular
  											purpose. The entire risk arising out of the use or performance of the sample scripts and
  											documentation remains with you. In no event shall I be liable for any damages whatsoever
  											(including, without limitation, damages for loss of business profits, business interruption,
  											loss of business information, or other pecuniary loss) arising out of the use of or inability
  											to use the script or documentation.
  Assumptions					: ExecutionPolicy of AllSigned (recommended), RemoteSigned or Unrestricted (not recommended)
  Limitations					:
  Known issues				: None yet, but I'm sure you'll find some!
  Acknowledgements 		:

.LINK


.EXAMPLE
	PS C:\> Get-ScriptUpdates -ChangeLogURL 1234 -Age 45

	Description
	-----------
	Executes the function, specifying the article number the user will be taken to if they choose yes to go online, as well as number of days that must have elapsed.

.INPUTS
	None. You cannot pipe objects to this function.

.OUTPUTS
	Text output
#>

	[CmdletBinding(SupportsShouldProcess = $True)]
	param (
		# Specifies the article number the user will be taken to if they choose yes to go online.
		[Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[int] $ChangelogUrl,

		# Specifies the number of days that must have elapsed before the prompt is displayed.
		[Parameter(Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[int] $Age = 90,

		[Parameter(Position = 2, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string] $FilePath = $MyInvocation.ScriptName
	)

	BEGIN{
		# Executes once before first item in pipeline is processed
		# the $_ variable represents the current input object
		[string]$Check4UpdatesPrompt = @"
┌──────────────────────────────────────────────────────────┐
│                Check For Updates?                        │
│            ==========================                    │
│    This script is more than $Age days old. Would you       │
│    like to check the script's website for a              │
│    newer version?                                        │
│                                                          │
└──────────────────────────────────────────────────────────┘
"@
	} # end BEGIN

	PROCESS{
		# Executes once for each pipeline object
		# the $_ variable represents the current input object
		# echo $_
		if (((Get-Date) - (Get-Item $filepath).CreationTime).TotalDays -gt $age){
			Write-Host $Check4UpdatesPrompt -ForegroundColor Green
			if ((Read-host "Go online? [y/n]") -imatch "y"){
				Start-Process "http://www.ehloworld.com/$ChangelogUrl"
			}
		}
	} # end PROCESS

	END{
		# Executes once after last pipeline object is processed
		# the $_ variable represents the current input object
	} # end END
} # end function Test-ScriptUpdates

#endregion functions

if ((-not(Test-IsSigned)) -and (-not $SkipUpdateCheck)){
	Test-ScriptUpdates -ChangelogUrl 681 -Age 90
}

Set-ModuleStatus -name Lync
if ($UserHighConnectionFlag){
	# We have to target the global policy or environments with more than one CsRegistrarConfiguration will barf
	$MaxEndPointsPerUser = (Get-CsRegistrarConfiguration -Identity Global).MaxEndPointsPerUser
	if ($UserHighConnectionFlag -gt $MaxEndPointsPerUser){
		Write-Host "MaxEndPointsPerUser in the global configuration is $MaxEndPointsPerUser. Please specify a number for UserHighConnectionFlag that does not exceed $MaxEndPointsPerUser. You specified $UserHighConnectionFlag." -ForegroundColor Red
		exit
	}
}
if ((! $server) -and (! $PoolFqdn) -and ((Get-CsService -Registrar | Measure-Object).count -eq 1)){
	Write-Verbose "Retrieving pool info"
	$PoolFqdn = (Get-CsService -Registrar).PoolFqdn
	Write-Verbose "Pool is now set to $PoolFqdn"
}
if ((! $server) -and (! $PoolFqdn)){
	$PoolFqdn = Read-Host "Enter front end pool FQDN"
	Write-Verbose "Pool is now set to $PoolFqdn"
}

#################################################################################################
########################################  Main Program  #########################################
#################################################################################################
# Here is where we pull all the front end server(s) from our topology for the designated
# pool and iterate through them to get current connections from all the servers.
#
# There are several possibilities here:
#	 1. Have collection of frontend servers
#	 2. Have a single frontend server or
#	 3. Have no servers
#  4. User specified a server instead of a pool

if ($PoolFqdn -and (! $server)){
	# set FQDN if $PoolFqdn was specified as just the netbios name
	if (!($PoolFqdn -match "\.")){
		Write-Verbose "No FQDN supplied. Building it. This may not work if the pool domain is different than this computer's domain"
		$PoolFqdn = $PoolFqdn+"."+([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).name
	}
	Write-Host "`n`nChecking these pool servers in pool: " -ForegroundColor Cyan -NoNewLine
	Write-Host $PoolFqdn
	$feServers = Get-CsComputer -Pool $PoolFqdn | Sort-Object identity
	ForEach ($feserver in $feservers){
		Write-Host $($feserver.identity) -ForegroundColor Yellow
	}
}elseif ($server -and (! $PoolFqdn)){
	if (!($server -match "\.")){
		Write-Verbose "No FQDN supplied. Building it. This may not work if the server domain is different than this computer's domain"
		$server = $server+"."+([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).name
	}
	$feServers = Get-CsComputer -Identity $server -ErrorAction SilentlyContinue
	Write-Host "`n`nChecking this server: " -ForegroundColor Cyan -NoNewLine
	Write-Host $server
}

# next line added as recommended by Tristan Griffiths
$OverallRecords = @()

if ($feServers.count) {
	# Frontend pool collection, iterate through them
	for ($i = 0; $i -lt $feServers.count; $i++) {
		if ($SipAddress) {
			if ((!($SipAddress -match "@"))-and ((Get-CsSipDomain | Measure-Object).count -eq 1)){
				Write-Verbose "Incomplete SIP address supplied. Building it."
				$SipAddress = $SipAddress+"@"+(Get-CsSipDomain).identity
				Write-Verbose "SIP address corrected to $SipAddress"
			}
			Write-Verbose "Gathering info from $($feServers[$i].identity)"
			$data = Get-Data -SipAddress $SipAddress -Server $feServers[$i].identity -ClientVersion $ClientVersion
		} else {
			Write-Verbose "Gathering info from $($feServers[$i].identity)"
			$data = Get-Data -Server $feServers[$i].identity -ClientVersion $ClientVersion
		}

		# Since an individual user's connections are all homed on one server,
		# we won't have data coming back from all front-end servers in the
		# case of searching for a single user
		if ($data) {
			$OverallRecords = $OverallRecords + $data
		}
	}
} elseif ($feServers) {
	# Have a standalone server or a FE pool of only one server
	if ($SipAddress) {
		if ((!($SipAddress -match "@"))-and ((Get-CsSipDomain | Measure-Object).count -eq 1)){
			Write-Verbose "Incomplete SIP address supplied. Building it."
			$SipAddress = $SipAddress+"@"+(Get-CsSipDomain).identity
			Write-Verbose "SIP address corrected to $SipAddress"
		}
		$data = Get-Data -SipAddress $SipAddress -Server $feServers.identity -ClientVersion $ClientVersion
	} else {
		Write-Verbose "Gathering info from $($feServers.identity)"
		$data = Get-Data -Server $feServers.identity -ClientVersion $ClientVersion
	}

	# Make sure we have data to work with...
	if ($data) {
		$OverallRecords = $data
	}
}else{
	Write-Host "No servers returned!" -ForegroundColor Red
}

# Check to see if we have any data to act on
if (! $OverallRecords) {
	Write-Host "`r`nNothing returned from query!`r`n" -ForegroundColor Yellow

	# Nothing else to do
	exit
} else {
	$count = 0
	$userHash = @{}
	$clientHash = @{}
	$serverHash = @{}
	$UserList = @{}

	$OverallRecords | ForEach-object {
		# Each record has three components: Connected Client Version, User's SIP
		# address and the frontend server's FQDN. Here, we'll build a hash
		# for each of these components for each record.

		# Build hash of users

 		$UserList = $_.UserName

		if (! $userHash.ContainsKey($_.UserName)) {
			$userHash.add($_.UserName, 1)
		} else {
			$userHash.set_item($_.UserName, ($userHash.get_item($_.UserName) + 1))
		}

		# Build hash of servers
		if (! $serverHash.ContainsKey($_.fqdn)) {
			$serverHash.add($_.fqdn, 1)
		} else {
			$serverHash.set_item($_.fqdn, ($serverHash.get_item($_.fqdn) + 1))
		}

		# Build hash of clients
		# Lets get rid of the extraneous verbage from the client version names, if applicable
		# This merely gives a friendlier output, and helps prevent wordwrap
		if ($_.ClientVersion.contains('(') -and (! $ShowFullClient)) {
			# Get rid of extraneous verbage
			$clientName = $_.ClientVersion.substring(0, $_.ClientVersion.IndexOf('('))
		} else {
			# Have a client name with no extraneous verbage or $ShowFullClient switch specified
			$clientName = $_.ClientVersion
			$clientName = $clientName.replace("Microsoft ","")
			$clientName = $clientName.replace("Office ","")
			$clientName = $clientName.replace("AndroidLync","Android")
			$clientName = $clientName.replace("iPadLync","iPad")
			$clientName = $clientName.replace("iPhoneLync","iPhone")
			$clientName = $clientName.replace("WPLync","WP")
		}

		if (! $clientHash.ContainsKey($clientName)) {
			$clientHash.add($clientName, 1)
		} else {
			$clientHash.set_item($ClientName, ($clientHash.get_item($ClientName) + 1))
		}
		$count++
	}
}

#################################################################################################
####################################  Output Query Results  #####################################
#################################################################################################
# If output to file is chosen, then write out the results and a note to that effect
# then exit

if ($FilePath) {
	$OverallRecords | Export-Csv $FilePath
	Write-Host -ForegroundColor green "`r`nQuery Results written to $FilePath`r`n"
	exit
}

#region ClientVersions
if (! $ShowFullClient){
	Write-Host ("`r`n`r`n{0, -26}{1, -41}{2, 11}" -f "Client Version", "Agent", "Connections") -ForegroundColor Cyan
}else{
	Write-Host ("`r`n`r`n{0, -64}{1, 14}" -f "Agent", "Connections") -ForegroundColor cyan
}
Write-Host "------------------------------------------------------------------------------" -ForegroundColor Cyan

ForEach ($key in $clientHash.keys | Sort-Object -Descending) {
	# Break down client version into its two component parts and print
	# them out along with their respective counts in a nice format
	$index = $key.indexof(" ")

	if ($index -eq "-1") {
		# No second part
		$first = $key
		$second = " "
	} else {
		# Client version/agent has two main parts
		$first = $key.substring(0, $index)
		$second = $key.substring($index + 1)
	}

	$value = $clientHash.$key
	if (! $ShowFullClient){
		"{0,-26}{1,-45}{2,7}" -f $($first.trim()), $($second.trim()), $value
	}else{
		"{0,-73}{1,4}" -f $($second.trim()), $value
	}
}
 Write-Host "------------------------------------------------------------------------------" -ForegroundColor Cyan
# "{0,-41}{1,37}" -f "Client Versions Connected", $clientHash.count
#endregion ClientVersions


#region FrontEnds
# Frontend Server, Connections
Write-Host ("`r`n`r`n{0,-41}{1,15}" -f "Front End Servers", "Connections") -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
ForEach ($key in ($serverHash.keys | Sort-Object)) {
	$value = $serverHash.$key
	[string]$Percent = "("+"{0:P2}" -f ($value/$count)+")"
	"{0,-40}{1,6} {2,9}" -f $($key.ToLower()), $value, $Percent
}
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
"{0,-40}{1,6}" -f "Total connections", $count
#endregion FrontEnds

#region UniqueUsers
# Unique Users, Unique Clients
$UniqueUsers = $userHash.count
Write-Host ("`r`n`r`n{0,-41}{1,15}" -f "Total Unique Users/Clients", "Total") -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
"{0,-41}{1,15}" -f "Users Connected", $userHash.count
#endregion UniqueUsers

#region ShowTotal
if ($ShowTotal){
	Write-Host "Calculating data..." -ForegroundColor Yellow -NoNewline
	[int]$TotalUsers = (Get-CsUser | Measure-Object).count
	[int]$TotalEVUsers = (Get-CsUser -filter {EnterpriseVoiceEnabled -eq $True} | Measure-Object).Count
	[string]$TotalPercent = "{0:P2}" -f ($UniqueUsers/$TotalUsers)
	Write-Host "`b`b`b`b`b`b`b`b`b`b`b`b`b`b`b`b`b`b`b" -NoNewline
	"{0,-41}{1,15}" -f "Lync Enabled Users (Entire organization)", $TotalUsers
	"{0,-41}{1,15}" -f "Voice Enabled Users (Entire organization)", $TotalEVUsers
	"{0,-41}{1,15}" -f "Percentage of Enabled Users Connected", $TotalPercent
}
"{0,-41}{1,15}" -f "Client Versions Connected", $clientHash.count
Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
#endregion ShowTotal

#region IncludeUsers
# Users, Connections
if ($IncludeUsers){
	Write-Host ("`r`n`r`n{0,-45}{1,-11}" -f "Connected Users", "Connections") -ForegroundColor Cyan
	Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
	ForEach ($key in $userHash.keys | Sort-Object) {
		$value = $userHash.$key
		if ($value -ge $UserHighConnectionFlag){
 			Write-Host ("{0,-45}{1,11}" -f $key, $value) -ForegroundColor Red
		}else{
			"{0,-45}{1,11}" -f $key, $value
		}
	}
	Write-Host "--------------------------------------------------------`r`n" -ForegroundColor Cyan
}
#endregion IncludeUsers

#region HighUsers
# Users, Connections
if ($IncludeHighUsers){
	Write-Host ("`r`n`r`n{0,-45}{1,-11}" -f "Connected Users", "Connections") -ForegroundColor Cyan
	Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
	ForEach ($key in $userHash.keys | Sort-Object) {
		$value = $userHash.$key
		if ($value -eq $UserHighConnectionFlag){
 			"{0,-45}{1,11}" -f $key, $value
		}elseif ($value -gt $UserHighConnectionFlag){
			Write-Host ("{0,-45}{1,11}" -f $key, $value) -ForegroundColor Red
		}
	}
	Write-Host "--------------------------------------------------------`r`n" -ForegroundColor Cyan
}
#endregion HighUsers

#region SipAddress
if ($SipAddress){
	Write-Host "`r`n`r`n"
	# we have to get creative here as the output from Get-CsUserPoolInfo changed from Lync 2010 to 2013
	if (((Get-Module Lync).Version).Major -eq 4){
		# Lync Server 2010
		$UserPreferredInfo = Get-CsUserPoolInfo -Identity sip:$SipAddress | Select-Object -ExpandProperty PrimaryPoolMachinesInPreferredOrder | Select-Object MachineId,Fqdn
		Write-Host ("{0,-40}" -f "Preferred Connection Order For $SipAddress") -ForegroundColor Cyan
		Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
		ForEach ($server in $UserPreferredInfo){
			$machineid = $server.machineid
			$fqdn = $server.fqdn
			"{0,-40}" -f $fqdn
		}
	}elseif (((Get-Module Lync).Version).Major -eq 5){
		# Lync Server 2013
		$UserPreferredInfo = Get-CsUserPoolInfo -Identity sip:$SipAddress | Select-Object -ExpandProperty PrimaryPoolMachinesInPreferredOrder
		Write-Host ("{0,-40}" -f "Preferred Connection Order For $SipAddress") -ForegroundColor Cyan
		Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
		ForEach ($server in $UserPreferredInfo){
			"{0,-40}" -f $server
		}
	}
	Write-Host "--------------------------------------------------------`n" -ForegroundColor Cyan
}
#region SipAddress
Write-Verbose "Query complete"

Remove-ScriptVariables($MyInvocation.MyCommand.Definition)
# SIG # Begin signature block
# MIINGgYJKoZIhvcNAQcCoIINCzCCDQcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUU/pfomldC4nIJG2C6stAPiV4
# NV6gggpcMIIFJDCCBAygAwIBAgIQCW4jPbUU7ejqppBXGijcKjANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE1MDkwOTAwMDAwMFoXDTE2MTEx
# NjEyMDAwMFowazELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAk1JMRkwFwYDVQQHExBT
# dGVybGluZyBIZWlnaHRzMRkwFwYDVQQKExBJbm5lcnZhdGlvbiwgTExDMRkwFwYD
# VQQDExBJbm5lcnZhdGlvbiwgTExDMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAvqXtZp4VZgIWqr6ju9BVcQ6MP7D5WyBmKSypjLNJ5PhZBjL0YiusEGHg
# 8auFojul0DSJngc9SM368BQib+SVHtlCTOP6M6j9Q5N7t3GYsROj3sc16/yRRM1i
# g3vmhcHzNWVJ6X68D3DeQl4tv3MpantuRxiktTmTBSlAtF/8YGxKJv0cNNq4JC3c
# k6MqY/5Q1dYdH9CrD/P40gaOnZazFxNYjhb5rK5caMxL4djzbwfZGSvTYedGX60g
# 3bq99B6jqRgvYTU7C4lI3gWtmh15sSw1Tdf0RKKpqwPwOy5gCWTcqKlTTJVqoQR8
# /haMjfUItRTi+CIwEnE3/i6R36C95wIDAQABo4IBuzCCAbcwHwYDVR0jBBgwFoAU
# WsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYEFBpQMLQFvMYa0UjlMqp9Etla
# c9zYMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8E
# cDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVk
# LWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTIt
# YXNzdXJlZC1jcy1nMS5jcmwwQgYDVR0gBDswOTA3BglghkgBhv1sAwEwKjAoBggr
# BgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzCBhAYIKwYBBQUH
# AQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYI
# KwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNI
# QTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqG
# SIb3DQEBCwUAA4IBAQAaw825iLtpqFCRUCJqAdyKAYB568K8HhviRfAcmj8aUcFD
# 012Co2BQbLgjtK2M+S1bByF4q7jX+4NIOT7hufi96udDXRPfAaCzYoNOqW9ihnwr
# iAfYDC2Z2z9LWrrKQx6peZQYV4U4Mf5QpiVX+rfHWAZLPy5QYNrkoNJ5xxlA3K8N
# yL1VtfUUrWQnVkhfnt0uE9xNaCZOUEUHGmIc8yZeD6IohX8+OEOe7c+lEyz87M2D
# RK9dzIYzOKPBXOSch29ijLoG2zoGR5fkrEVvLvFYzykQp00TTjdCyx0QP7Jkm42v
# mOXck7Zzcr9rKPyBETvJ4Ix7YmGJhHTQdLLcxMI8MIIFMDCCBBigAwIBAgIQBAkY
# G1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQw
# IgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIw
# MDAwWhcNMjgxMDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhE
# aWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrb
# RPV/5aid2zLXcep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdglrA55KDp+6dFn08b7
# KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRniolF1C2ho+mILCCV
# rhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXp
# dOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWO
# D8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IB
# zTCCAckwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1Ud
# HwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0gBEgwRjA4BgpghkgB
# hv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9D
# UFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8G
# A1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IB
# AQA+7A1aJLPzItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew
# 4fbRknUPUbRupY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQGivecRk5c/5CxGwcO
# kRX7uq+1UcKNJK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEehemhor5unXCBc2XGx
# DI+7qPjFEmifz0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJRZboWR3p+nRka7Lr
# ZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiF
# LpKR6mhsRDKyZqHnGKSaZFHvMYICKDCCAiQCAQEwgYYwcjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmlu
# ZyBDQQIQCW4jPbUU7ejqppBXGijcKjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUQ1SsMcnCzL7f
# U53sb8HINJpJW5IwDQYJKoZIhvcNAQEBBQAEggEAP8zBP0eJUGYeXxg+SD11nhFm
# k548OKzqJJvt3J56dqEP3FGxLovZe6+hl2VB/Owa9sB0RO/YhuMoK5zIgRHW1zQK
# vplGOq3JqKLbHNKFTP5MfBYg7hySh4nNE3EMPb1zBulGiSrWJEZ5X+jlvaioWQoY
# xjbl2D8HOfdHqyVvRhugSbk0RKBeIC60+ecrZ+QmXrgDBqQVD53wPtn9rRto7H5B
# jCaLnP2fcgAdocOZ8RCkYwpShfuRiIhsULboM5fu6wD4DylT2cSZPJScnujj+tc+
# w0r3aDDcYWp8DwXgc1S+f3jXq0T7+it/ekB20vIbEBXkyodr/K2WPtNwAoSqaw==
# SIG # End signature block
