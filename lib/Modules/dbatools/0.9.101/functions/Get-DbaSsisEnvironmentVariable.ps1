function Get-DbaSsisEnvironmentVariable {
	<#
.SYNOPSIS
This command gets specified SSIS Environment and all its variables

.DESCRIPTION
This command gets all variables from specified environment from SSIS Catalog. All sensitive values are decrypted.
The function communicates directly with SSISDB database, "SQL Server Integration Services" service isn't queried there.
Each parameter (besides SqlInstance and SqlCredential) acts as the filter to only include or exclude particular element

.PARAMETER SqlInstance
SQLServer name or SMO object representing the SQL Server to connect to. 
This can be a collection and receive pipeline input to allow the function
to be executed against multiple SQL Server instances.

.PARAMETER SqlCredential
SqlCredential object to connect as. If not specified, current Windows login will be used.

.PARAMETER Environment
The SSIS Environments names that we want to get variables from

.PARAMETER EnvironmentExclude
The SSIS Environments to exclude. Acts as a filter for environments, best used without 'Environment' parameter 
to get variables for all environments but excluded ones

.PARAMETER Folder
The Folders names that contain the environments

.PARAMETER FolderExclude
The Folders names to exclude. Acts as a filter for folders containing environments, best user without 'Folder' parameter
to get variables for all folders but excluded ones

.PARAMETER EnableException
		By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
		This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
		Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.
		
.EXAMPLE
Get-DbaSsisEnvironmentVariable -SqlInstance localhost -Environment DEV -Folder DWH_ETL

Gets variables of 'DEV' environment located in 'DWH_ETL' folder on 'localhost' Server

.EXAMPLE
Get-DbaSsisEnvironmentVariable -SqlInstance localhost -Environment DEV -Folder DWH_ETL, DEV2, QA

Gets variables of 'DEV' environment(s) located in folders 'DWH_ETL', 'DEV2' and 'QA' on 'localhost' server

.EXAMPLE
Get-DbaSsisEnvironmentVariable -SqlInstance localhost -Environment DEV -FolderExclude DWH_ETL, DEV2, QA

Gets variables of 'DEV' environments located in folders other than 'DWH_ETL', 'DEV2' and 'QA' on 'localhost' server

.EXAMPLE
Get-DbaSsisEnvironmentVariable -SqlInstance localhost -Environment DEV, PROD -Folder DWH_ETL, DEV2, QA

Gets variables of 'DEV' and 'PROD' environment(s) located in folders 'DWH_ETL', 'DEV2' and 'QA' on 'localhost' server

.EXAMPLE
Get-DbaSsisEnvironmentVariable -SqlInstance localhost -EnvironmentExclude DEV, PROD -Folder DWH_ETL, DEV2, QA

Gets variables of environments other than 'DEV' and 'PROD' located in folders 'DWH_ETL', 'DEV2' and 'QA' on 'localhost' server

.EXAMPLE
Get-DbaSsisEnvironmentVariable -SqlInstance localhost -EnvironmentExclude DEV, PROD -FolderExclude DWH_ETL, DEV2, QA

Gets variables of environments other than 'DEV' and 'PROD' located in folders other than 'DWH_ETL', 'DEV2' and 'QA' on 'localhost' server

.EXAMPLE
'localhost' | Get-DbaSsisEnvironmentVariable -EnvironmentExclude DEV, PROD

Gets all SSIS environments except 'DEV' and 'PROD' from 'localhost' server. The server name comes from pipeline

.EXAMPLE
'SRV1', 'SRV3' | Get-DbaSsisEnvironmentVariable

Gets all SSIS environments from 'SRV1' and 'SRV3' servers. The server's names come from pipeline

.EXAMPLE
'SRV1', 'SRV2' | Get-DbaSsisEnvironmentVariable DEV | Out-GridView

Gets all variables from 'DEV' Environment(s) on servers 'SRV1' and 'SRV2' and outputs it as the GridView. 
The server names come from the pipeline.

.EXAMPLE
'localhost' | Get-DbaSsisEnvironmentVariable -EnvironmentExclude DEV, PROD | Select-Object -Property Name, Value | Where-Object {$_.Name -match '^a'} | Out-GridView

Gets all variables from Environments other than 'DEV' and 'PROD' on 'localhost' server, 
selects Name and Value properties for variables that names start with letter 'a' and outputs it as the GridView

.NOTES
Tags:
Author: Bartosz Ratajczyk ( @b_ratajczyk )
dbatools PowerShell module (https://dbatools.io)
Copyright (C) 2016 Chrissy LeMaire
License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0
#>
	[CmdletBinding()]
	Param (
		[parameter(Mandatory, ValueFromPipeline)]
		[Alias('SqlServer', 'ServerInstance')]
		[DbaInstanceParameter[]]$SqlInstance,
		[Parameter(Mandatory = $false)]
		[PSCredential]$SqlCredential,
		[parameter(Mandatory = $false)]
		[object[]]$Environment,
		[parameter(Mandatory = $false)]
		[object[]]$EnvironmentExclude,
		[parameter(Mandatory = $false)]
		[object[]]$Folder,
		[parameter(Mandatory = $false)]
		[object[]]$FolderExclude,
		[switch][Alias('Silent')]$EnableException
	)
	
	process {
		foreach ($instance in $SqlInstance) {
			try {
				Write-Message -Message "Connecting to $instance" -Level Verbose
				$server = Connect-SqlInstance -SqlInstance $instance -MinimumVersion 11
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}
			
			try {
				$ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"
				
				Write-Message -Message "Connecting to SSIS Catalog on $instance" -Level Verbose
				$SSIS = New-Object "$ISNamespace.IntegrationServices" $server
			}
			catch {
				Stop-Function -Message "Could not connect to SSIS Catalog on $instance or current SMO library does not support SSIS catalog"
				return
			}
			
			Write-Message -Message "Fetching SSIS Catalog and its folders" -Level Verbose
			$catalog = $SSIS.Catalogs | Where-Object { $_.Name -eq "SSISDB" }
			
			# get all folders names if none provided
			if ($null -eq $Folder) {
				$searchFolders = $catalog.Folders.Name
			}
			else {
				$searchFolders = $Folder
			}
			
			# filter unwanted folders
			if ($FolderExclude) {
				$searchFolders = $searchFolders | Where-Object { $_ -notin $FolderExclude }
			}
			
			if ($null -eq $searchFolders) {
				Write-Message -Message "Instance: $instance > -Folder and -FolderExclude filters return an empty collection. Skipping" -Level Warning
			}
			else {
				foreach ($f in $searchFolders) {
					# get all environments names if none provided
					if ($null -eq $Environment) {
						$searchEnvironments = $catalog.Folders.Environments.Name
					}
					else {
						$searchEnvironments = $Environment
					}
					
					#filter unwanted environments
					if ($EnvironmentExclude) {
						$searchEnvironments = $searchEnvironments | Where-Object { $_ -notin $EnvironmentExclude }
					}
					
					if ($null -eq $searchEnvironments) {
						Write-Message -Message "Instance: $instance / Folder: $f > -Environment and -EnvironmentExclude filters return an empty collection. Skipping." -Level Warning
					}
					else {
						$Environments = $catalog.Folders[$f].Environments | Where-Object { $_.Name -in $searchEnvironments }
						
						foreach ($e in $Environments) {
							#encryption handling
							$encKey = 'MS_Enckey_Env_' + $e.EnvironmentId
							$encCert = 'MS_Cert_Env_' + $e.EnvironmentId
							
							<#
                            SMO does not return sensitive values (gets data from catalog.environment_variables)
                            We have to manually query internal.environment_variables instead and use symmetric keys
                            within T-SQL code
                            #>
							
							$sql = @"
                                OPEN SYMMETRIC KEY $encKey DECRYPTION BY CERTIFICATE $encCert;

                                SELECT
                                    ev.variable_id,
                                    ev.name,
                                    ev.description,
                                    ev.type,
                                    ev.sensitive,
                                    value			= ev.value,
                                    ev.sensitive_value,
                                    ev.base_data_type,
                                    decrypted		= decrypted.value
                                FROM internal.environment_variables ev

                                    CROSS APPLY (
                                        SELECT
                                            value	= CASE base_data_type
                                                        WHEN 'nvarchar' THEN CONVERT(NVARCHAR(MAX), DECRYPTBYKEY(sensitive_value))
                                                        WHEN 'bit' THEN CONVERT(NVARCHAR(MAX), CONVERT(bit, DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'datetime' THEN CONVERT(NVARCHAR(MAX), CONVERT(datetime2(0), DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'single' THEN CONVERT(NVARCHAR(MAX), CONVERT(DECIMAL(38, 18), DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'float' THEN CONVERT(NVARCHAR(MAX), CONVERT(DECIMAL(38, 18), DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'decimal' THEN CONVERT(NVARCHAR(MAX), CONVERT(DECIMAL(38, 18), DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'tinyint' THEN CONVERT(NVARCHAR(MAX), CONVERT(tinyint, DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'smallint' THEN CONVERT(NVARCHAR(MAX), CONVERT(smallint, DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'int' THEN CONVERT(NVARCHAR(MAX), CONVERT(INT, DECRYPTBYKEY(sensitive_value)))
                                                        WHEN 'bigint' THEN CONVERT(NVARCHAR(MAX), CONVERT(bigint, DECRYPTBYKEY(sensitive_value)))
                                                    END
                                    ) decrypted

                                WHERE environment_id = $($e.EnvironmentId);

                                CLOSE SYMMETRIC KEY $encKey;
"@
							
							$ssisVariables = $server.Query($sql, "SSISDB")
							
							foreach ($variable in $ssisVariables) {
								if ($variable.sensitive -eq $true) {
									$value = $variable.decrypted
								}
								else {
									$value = $variable.value
								}
								
								[PSCustomObject]@{
									ComputerName = $server.NetName
									InstanceName = $server.ServiceName
									SqlInstance  = $server.DomainInstanceName
									Folder       = $f
									Environment  = $e.Name
									Id           = $variable.variable_id
									Name         = $variable.Name
									Description  = $variable.description
									Type         = $variable.type
									IsSensitive  = $variable.sensitive
									BaseDataType = $variable.base_data_type
									Value        = $value
								}
							}
						}
					}
				}
			}
		}
	}
}