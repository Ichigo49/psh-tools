function Connect-SqlInstance {
    <#
        .SYNOPSIS
            Internal function to establish smo connections.
        
        .DESCRIPTION
            Internal function to establish smo connections.
    
            Can interpret any of the following types of information:
            - String
            - Smo Server objects
            - Smo Linked Server objects
        
        .PARAMETER SqlInstance
            The SQL Server instance to restore to.

        .PARAMETER SqlCredential
            Allows you to login to servers using SQL Logins as opposed to Windows Auth/Integrated/Trusted. 
        
        .PARAMETER ParameterConnection
            Whether this call is for dynamic parameters only.
        
        .PARAMETER RegularUser
            The connection doesn't require SA privileges.
            By default, the assumption is that SA is required.
    
        .PARAMETER MinimumVersion
           The minimum version that the calling command will support
	
        .EXAMPLE
            Connect-SqlInstance -SqlInstance sql2014
    
            Connect to the Server sql2014 with native credentials.
    #>
	
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][object]$SqlInstance,
		[object]$SqlCredential,
		[switch]$ParameterConnection,
		[switch]$RegularUser = $true,
		[int]$MinimumVersion
	)
	
	#region Utility functions
	function Invoke-TEPPCacheUpdate {
		[CmdletBinding()]
		Param (
			[System.Management.Automation.ScriptBlock]
			$ScriptBlock
		)
		
		try {
			[ScriptBlock]::Create($scriptBlock).Invoke()
		}
		catch {
			# If the SQL Server version doesn't support the feature, we ignore it and silently continue
			if ($_.Exception.InnerException.InnerException.GetType().FullName -eq "Microsoft.SqlServer.Management.Sdk.Sfc.InvalidVersionEnumeratorException") {
				return
			}
			
			if ($ENV:APPVEYOR_BUILD_FOLDER -or ([Sqlcollaborative.Dbatools.dbaSystem.DebugHost]::DeveloperMode)) { throw }
			<#
			elseif ([Sqlcollaborative.Dbatools.dbaSystem.DebugHost]::DevelopmentBranch) {
				Write-Message -Level Warning -Message "Failed TEPP Caching: $($s | Select-String '"(.*?)"' | ForEach-Object { $_.Matches[0].Groups[1].Value })" -ErrorRecord $_ -EnableException $false
			}
			#>
			else {
				Write-Message -Level Warning -Message "Failed TEPP Caching: $($scriptBlock.ToString() | Select-String '"(.*?)"' | ForEach-Object { $_.Matches[0].Groups[1].Value })" -ErrorRecord $_ 3>$null
			}
		}
	}
	#endregion Utility functions
	
	#region Ensure Credential integrity
    <#
    Usually, the parameter type should have been not object but off the PSCredential type.
    When binding null to a PSCredential type parameter on PS3-4, it'd then show a prompt, asking for username and password.
    
    In order to avoid that and having to refactor lots of functions (and to avoid making regular scripts harder to read), we created this workaround.
    #>
	if ($SqlCredential) {
		if ($SqlCredential.GetType() -ne [System.Management.Automation.PSCredential]) {
			throw "The credential parameter was of a non-supported type! Only specify PSCredentials such as generated from Get-Credential. Input was of type $($SqlCredential.GetType().FullName)"
		}
	}
	#endregion Ensure Credential integrity
	
	#region Safely convert input into instance parameters
    <#
    This is a bit ugly, but:
    In some cases functions would directly pass their own input through when the parameter on the calling function was typed as [object[]].
    This would break the base parameter class, as it'd automatically be an array and the parameterclass is not designed to handle arrays (Shouldn't have to).
    
    Note: Multiple servers in one call were never supported, those old functions were liable to break anyway and should be fixed soonest.
    #>
	if ($SqlInstance.GetType() -eq [Sqlcollaborative.Dbatools.Parameter.DbaInstanceParameter]) {
		[DbaInstanceParameter]$ConvertedSqlInstance = $SqlInstance
	}
	else {
		[DbaInstanceParameter]$ConvertedSqlInstance = [DbaInstanceParameter]($SqlInstance | Select-Object -First 1)
		
		if ($SqlInstance.Count -gt 1) {
			Write-Message -Level Warning -EnableException $true -Message "More than on server was specified when calling Connect-SqlInstance from $((Get-PSCallStack)[1].Command)"
		}
	}
	#endregion Safely convert input into instance parameters
	
	#region Input Object was a server object
	if ($ConvertedSqlInstance.InputObject.GetType() -eq [Microsoft.SqlServer.Management.Smo.Server]) {
		$server = $ConvertedSqlInstance.InputObject
		if ($server.ConnectionContext.IsOpen -eq $false) {
			$server.ConnectionContext.Connect()
		}
		
		# Register the connected instance, so that the TEPP updater knows it's been connected to and starts building the cache
		[Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::SetInstance($ConvertedSqlInstance.FullSmoName.ToLower(), $server.ConnectionContext.Copy(), ($server.ConnectionContext.FixedServerRoles -match "SysAdmin"))
		
		# Update cache for instance names
		if ([Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::Cache["sqlinstance"] -notcontains $ConvertedSqlInstance.FullSmoName.ToLower()) {
			[Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::Cache["sqlinstance"] += $ConvertedSqlInstance.FullSmoName.ToLower()
		}
		
		# Update lots of registered stuff
		if (-not [Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::TeppSyncDisabled) {
			$FullSmoName = $ConvertedSqlInstance.FullSmoName.ToLower()
			foreach ($scriptBlock in ([Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::TeppGatherScriptsFast)) {
				Invoke-TEPPCacheUpdate -ScriptBlock $scriptBlock
			}
		}
		return $server
	}
	#endregion Input Object was a server object
	
	#region Input Object was anything else
	# This seems a little complex but is required because some connections do TCP,SqlInstance
	$loadedSmoVersion = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like "Microsoft.SqlServer.SMO,*" }
	
	if ($loadedSmoVersion) {
		$loadedSmoVersion = $loadedSmoVersion | ForEach-Object {
			if ($_.Location -match "__") {
				((Split-Path (Split-Path $_.Location) -Leaf) -split "__")[0]
			}
			else {
				((Get-ChildItem -Path $_.Location).VersionInfo.ProductVersion)
			}
		}
	}
	
	$server = New-Object Microsoft.SqlServer.Management.Smo.Server $ConvertedSqlInstance.FullSmoName
	$server.ConnectionContext.ApplicationName = "dbatools PowerShell module - dbatools.io"
	if ($ConvertedSqlInstance.IsConnectionString) { $server.ConnectionContext.ConnectionString = $ConvertedSqlInstance.InputObject }
	
	try {
		$server.ConnectionContext.ConnectTimeout = [Sqlcollaborative.Dbatools.Connection.ConnectionHost]::SqlConnectionTimeout
		
		if ($SqlCredential.Username -ne $null) {
			$username = ($SqlCredential.Username).TrimStart("\")
			
			if ($username -like "*\*") {
				$username = $username.Split("\")[1]
				$authtype = "Windows Authentication with Credential"
				$server.ConnectionContext.LoginSecure = $true
				$server.ConnectionContext.ConnectAsUser = $true
				$server.ConnectionContext.ConnectAsUserName = $username
				$server.ConnectionContext.ConnectAsUserPassword = ($SqlCredential).GetNetworkCredential().Password
			}
			else {
				$authtype = "SQL Authentication"
				$server.ConnectionContext.LoginSecure = $false
				$server.ConnectionContext.set_Login($username)
				$server.ConnectionContext.set_SecurePassword($SqlCredential.Password)
			}
		}
	}
	catch { }
	
	try {
		$server.ConnectionContext.Connect()
	}
	catch {
		$message = $_.Exception.InnerException.InnerException
		if ($message) {
			$message = $message.ToString()
			$message = ($message -Split '-->')[0]
			$message = ($message -Split 'at System.Data.SqlClient')[0]
			$message = ($message -Split 'at System.Data.ProviderBase')[0]
			throw "Can't connect to $ConvertedSqlInstance`: $message "
		}
		else {
			throw $_
		}
	}
	
	if ($MinimumVersion -and $server.VersionMajor) {
		if ($server.versionMajor -lt $MinimumVersion) {
			throw "SQL Server version $MinimumVersion required - $server not supported."
		}
	}
	
	if (-not $RegularUser) {
		if ($server.ConnectionContext.FixedServerRoles -notmatch "SysAdmin") {
			throw "Not a sysadmin on $ConvertedSqlInstance. Quitting."
		}
	}
	
	if ($loadedSmoVersion -ge 11) {
		try {
			if ($Server.ServerType -ne 'SqlAzureDatabase') {
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Trigger], 'IsSystemObject')
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Schema], 'IsSystemObject')
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.SqlAssembly], 'IsSystemObject')
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Table], 'IsSystemObject')
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.View], 'IsSystemObject')
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.StoredProcedure], 'IsSystemObject')
				$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.UserDefinedFunction], 'IsSystemObject')
				
				if ($server.VersionMajor -eq 8) {
					# 2000
					$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Version')
					$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'CreateDate', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'Name', 'Sid', 'WindowsLoginAccessType')
				}
				elseif ($server.VersionMajor -eq 9 -or $server.VersionMajor -eq 10) {
					# 2005 and 2008
					$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
					$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
				}
				else {
					# 2012 and above
					$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], 'ReplicationOptions', 'ActiveConnections', 'AvailabilityDatabaseSynchronizationState', 'AvailabilityGroupName', 'BrokerEnabled', 'Collation', 'CompatibilityLevel', 'ContainmentType', 'CreateDate', 'ID', 'IsAccessible', 'IsFullTextEnabled', 'IsMirroringEnabled', 'IsUpdateable', 'LastBackupDate', 'LastDifferentialBackupDate', 'LastLogBackupDate', 'Name', 'Owner', 'PrimaryFilePath', 'ReadOnly', 'RecoveryModel', 'Status', 'Trustworthy', 'Version')
					$server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Login], 'AsymmetricKey', 'Certificate', 'CreateDate', 'Credential', 'DateLastModified', 'DefaultDatabase', 'DenyWindowsLogin', 'ID', 'IsDisabled', 'IsLocked', 'IsPasswordExpired', 'IsSystemObject', 'Language', 'LanguageAlias', 'LoginType', 'MustChangePassword', 'Name', 'PasswordExpirationEnabled', 'PasswordHashAlgorithm', 'PasswordPolicyEnforced', 'Sid', 'WindowsLoginAccessType')
				}
			}
		}
		catch {
			# perhaps a DLL issue, continue going	
		}
	}
	
	# Register the connected instance, so that the TEPP updater knows it's been connected to and starts building the cache
	[Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::SetInstance($ConvertedSqlInstance.FullSmoName.ToLower(), $server.ConnectionContext.Copy(), ($server.ConnectionContext.FixedServerRoles -match "SysAdmin"))
	
	# Update cache for instance names
	if ([Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::Cache["sqlinstance"] -notcontains $ConvertedSqlInstance.FullSmoName.ToLower()) {
		[Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::Cache["sqlinstance"] += $ConvertedSqlInstance.FullSmoName.ToLower()
	}
	
	# Update lots of registered stuff
	if (-not [Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::TeppSyncDisabled) {
		$FullSmoName = $ConvertedSqlInstance.FullSmoName.ToLower()
		foreach ($scriptBlock in ([Sqlcollaborative.Dbatools.TabExpansion.TabExpansionHost]::TeppGatherScriptsFast)) {
			Invoke-TEPPCacheUpdate -ScriptBlock $scriptBlock
		}
	}
	
	return $server
	#endregion Input Object was anything else
}