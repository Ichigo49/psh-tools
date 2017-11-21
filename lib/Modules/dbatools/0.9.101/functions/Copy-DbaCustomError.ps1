function Copy-DbaCustomError {
	<#
		.SYNOPSIS
			Copy-DbaCustomError migrates custom errors (user defined messages), by the custom error ID, from one SQL Server to another.

		.DESCRIPTION
			By default, all custom errors are copied. The -CustomError parameter is auto-populated for command-line completion and can be used to copy only specific custom errors.

			If the custom error already exists on the destination, it will be skipped unless -Force is used. The us_english version must be created first. If you drop the us_english version, all the other languages will be dropped for that specific ID as well.

		.PARAMETER Source
			Source SQL Server. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

		.PARAMETER SourceSqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

			$scred = Get-Credential, then pass $scred object to the -SourceSqlCredential parameter.

			Windows Authentication will be used if SourceSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER Destination
			Destination SQL Server. You must have sysadmin access and the server must be SQL Server 2000 or higher.

		.PARAMETER DestinationSqlCredential
			Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

			$dcred = Get-Credential, then pass this $dcred to the -DestinationSqlCredential parameter.

			Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

			To connect as a different Windows user, run PowerShell as that user.

		.PARAMETER CustomError
			The custom error(s) to process. This list is auto-populated from the server. If unspecified, all custom errors will be processed.

		.PARAMETER ExcludeCustomError
			The custom error(s) to exclude. This list is auto-populated from the server.

		.PARAMETER WhatIf
			If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

		.PARAMETER Confirm
			If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

		.PARAMETER EnableException
			By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
			This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
			Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
			
		.PARAMETER Force
			If this switch is enabled, the custom error will be dropped and recreated if it already exists on Destination.

		.NOTES
			Tags: Migration, CustomError
			Author: Chrissy LeMaire (@cl), netnerds.net
			Requires: sysadmin access on SQL Servers

			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Copy-DbaCustomError

		.EXAMPLE
			Copy-DbaCustomError -Source sqlserver2014a -Destination sqlcluster

			Copies all server custom errors from sqlserver2014a to sqlcluster using Windows credentials. If custom errors with the same name exist on sqlcluster, they will be skipped.

		.EXAMPLE
			Copy-DbaCustomError -Source sqlserver2014a -SourceSqlCredential $scred -Destination sqlcluster -DestinationSqlCredential $dcred -CustomError 60000 -Force

			Copies only the custom error with ID number 60000 from sqlserver2014a to sqlcluster using SQL credentials for sqlserver2014a and Windows credentials for sqlcluster. If a custom error with the same name exists on sqlcluster, it will be updated because -Force was used.

		.EXAMPLE
			Copy-DbaCustomError -Source sqlserver2014a -Destination sqlcluster -ExcludeCustomError 60000 -Force

			Copies all the custom errors found on sqlserver2014a except the custom error with ID number 60000 to sqlcluster. If a custom error with the same name exists on sqlcluster, it will be updated because -Force was used.

		.EXAMPLE
			Copy-DbaCustomError -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

			Shows what would happen if the command were executed using force.
	#>
	[CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldProcess = $true)]
	param (
		[parameter(Mandatory = $true)]
		[DbaInstanceParameter]$Source,
		[PSCredential]
		$SourceSqlCredential,
		[parameter(Mandatory = $true)]
		[DbaInstanceParameter]$Destination,
		[PSCredential]
		$DestinationSqlCredential,
		[object[]]$CustomError,
		[object[]]$ExcludeCustomError,
		[switch]$Force,
		[switch][Alias('Silent')]$EnableException
	)

	begin {

		$sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential
		$destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential

		$source = $sourceServer.DomainInstanceName
		$destination = $destServer.DomainInstanceName

		if ($sourceServer.VersionMajor -lt 9 -or $destServer.VersionMajor -lt 9) {
			throw "Custom Errors are only supported in SQL Server 2005 and above. Quitting."
		}
	}
	process {

		# US has to go first
		$orderedCustomErrors = @($sourceServer.UserDefinedMessages | Where-Object Language -eq "us_english")
		$orderedCustomErrors += $sourceServer.UserDefinedMessages | Where-Object Language -ne "us_english"
		$destCustomErrors = $destServer.UserDefinedMessages

		foreach ($currentCustomError in $orderedCustomErrors) {
			$customErrorId = $currentCustomError.ID
			$language = $currentCustomError.Language.ToString()
			
			$copyCustomErrorStatus = [pscustomobject]@{
				SourceServer		 = $sourceServer.Name
				DestinationServer    = $destServer.Name
				Type				 = "Custom error"
				Name				 = $currentCustomError
				Status			     = $null
				Notes			     = $null
				DateTime			 = [DbaDateTime](Get-Date)
			}
			
			if ( $CustomError -and ($customErrorId -notin $CustomError -or $customErrorId -in $ExcludeCustomError) ) {
				continue
			}

			if ($destCustomErrors.ID -contains $customErrorId) {
				if ($force -eq $false) {
					$copyCustomErrorStatus.Status = "Skipped"
					$copyCustomErrorStatus.Notes = "Already exists"
					$copyCustomErrorStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

					Write-Message -Level Verbose -Message "Custom error $customErrorId $language exists at destination. Use -Force to drop and migrate."
					continue
				}
				else {
					If ($Pscmdlet.ShouldProcess($destination, "Dropping custom error $customErrorId $language and recreating")) {
						try {
							Write-Message -Level Verbose -Message "Dropping custom error $customErrorId (drops all languages for custom error $customErrorId)"
							$destServer.UserDefinedMessages[$customErrorId, $language].Drop()
						}
						catch {
							$copyCustomErrorStatus.Status = "Failed"
							$copyCustomErrorStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

							Stop-Function -Message "Issue dropping custom error" -Target $customErrorId -InnerErrorRecord $_ -Continue
						}
					}
				}
			}

			if ($Pscmdlet.ShouldProcess($destination, "Creating custom error $customErrorId $language")) {
				try {
					Write-Message -Level Verbose -Message "Copying custom error $customErrorId $language"
					$sql = $currentCustomError.Script() | Out-String
					Write-Message -Level Debug -Message $sql
					$destServer.Query($sql)

					$copyCustomErrorStatus.Status = "Successful"
					$copyCustomErrorStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
				}
				catch {
					$copyCustomErrorStatus.Status = "Failed"
					$copyCustomErrorStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject

					Stop-Function -Message "Issue creating custom error" -Target $customErrorId -InnerErrorRecord $_
				}
			}
		}
	}
	end {
		Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Copy-SqlCustomError
	}
}
