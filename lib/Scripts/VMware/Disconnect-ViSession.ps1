Function Disconnect-ViSession {
	<#
	.SYNOPSIS
	Disconnects a connected vCenter Session.

	.DESCRIPTION
	Disconnects a open connected vCenter Session.

	.PARAMETER  SessionList
	A session or a list of sessions to disconnect.

	.EXAMPLE
	PS C:\> Get-VISession | Where { $_.IdleMinutes -gt 5 } | Disconnect-ViSession

	.EXAMPLE
	PS C:\> Get-VISession | Where { $_.Username -eq “User19” } | Disconnect-ViSession
	#>
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline=$true)]
		$SessionList
	)
	
	Process {
		$SessionMgr = Get-View $DefaultViserver.ExtensionData.Client.ServiceContent.SessionManager
		$SessionList | Foreach {
			Write-Output "Disconnecting Session for $($_.Username) which has been active since $($_.LoginTime)"
			$SessionMgr.TerminateSession($_.Key)
		}
	}
}