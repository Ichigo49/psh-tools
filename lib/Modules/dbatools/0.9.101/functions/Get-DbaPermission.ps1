function Get-DbaPermission {
	<#
		.SYNOPSIS
			Get a list of Server and Database level permissions

		.DESCRIPTION
			Retrieves a list of permissions

			Permissions link principals to securables.
			Principals exist on Windows, Instance and Database level.
			Securables exist on Instance and Database level.
			A permission state can be GRANT, DENY or REVOKE.
			The permission type can be SELECT, CONNECT, EXECUTE and more.

			See https://msdn.microsoft.com/en-us/library/ms191291.aspx for more information

		.PARAMETER SqlInstance
			The SQL Server that you're connecting to.

		.PARAMETER SqlCredential
			Credential object used to connect to the SQL Server as a different user

		.PARAMETER Database
			The database(s) to process - this list is auto-populated from the server. If unspecified, all databases will be processed.

		.PARAMETER ExcludeDatabase
			The database(s) to exclude - this list is auto-populated from the server

		.PARAMETER IncludeServerLevel
			Shows also information on Server Level Permissions

		.PARAMETER NoSystemObjects
			Excludes all permissions on system securables

		.PARAMETER EnableException 
				By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
				This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
				Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

		.NOTES
			Tags: Permissions, Databases
			Author: Klaas Vandenberghe ( @PowerDBAKlaas )

			Website: https://dbatools.io
			Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
			License: GNU GPL v3 https://opensource.org/licenses/GPL-3.0

		.LINK
			https://dbatools.io/Get-DbaPermission

		.EXAMPLE
			Get-DbaPermission -SqlInstance ServerA\sql987

			Returns a custom object with Server name, Database name, permission state, permission type, grantee and securable

		.EXAMPLE
			Get-DbaPermission -SqlInstance ServerA\sql987 | Format-Table -AutoSize

			Returns a formatted table displaying Server, Database, permission state, permission type, grantee, granteetype, securable and securabletype

		.EXAMPLE
			Get-DbaPermission -SqlInstance ServerA\sql987 -NoSystemObjects -IncludeServerLevel

			Returns a custom object with Server name, Database name, permission state, permission type, grantee and securable
			in all databases and on the server level, but not on system securables

		.EXAMPLE
			Get-DbaPermission -SqlInstance sql2016 -Database master

			Returns a custom object with permissions for the master database
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlServer")]
		[DbaInstance[]]$SqlInstance,
		[Alias("Credential")]
		[PSCredential]$SqlCredential,
		[Alias("Databases")]
		[object[]]$Database,
		[object[]]$ExcludeDatabase,
		[switch]$IncludeServerLevel,
		[switch]$NoSystemObjects,
		[switch][Alias('Silent')]$EnableException
	)
	begin {
		if ($NoSystemObjects) {
			$ExcludeSystemObjectssql = "WHERE major_id > 0 "
		}

		$ServPermsql = "SELECT SERVERPROPERTY('MachineName') AS ComputerName,
					   ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS InstanceName,
					   SERVERPROPERTY('ServerName') AS SqlInstance
						, [Database] = ''
						, [PermState] = state_desc
						, [PermissionName] = permission_name
						, [SecurableType] = COALESCE(o.type_desc,sp.class_desc)
						, [Securable] = CASE	WHEN class = 100 THEN @@SERVERNAME
												WHEN class = 105 THEN OBJECT_NAME(major_id)
												ELSE OBJECT_NAME(major_id)
												END
						, [Grantee] = SUSER_NAME(grantee_principal_id)
						, [GranteeType] = pr.type_desc
                        , [revokeStatement] = 'REVOKE ' + permission_name + ' ' + COALESCE(OBJECT_NAME(major_id),'') + ' FROM [' + SUSER_NAME(grantee_principal_id) + ']'
                        , [grantStatement] = 'GRANT ' + permission_name + ' ' + COALESCE(OBJECT_NAME(major_id),'') + ' TO [' + SUSER_NAME(grantee_principal_id) + ']'
					FROM sys.server_permissions sp
						JOIN sys.server_principals pr ON pr.principal_id = sp.grantee_principal_id
						LEFT OUTER JOIN sys.all_objects o ON o.object_id = sp.major_id

					$ExcludeSystemObjectssql

                    UNION ALL
                    SELECT	  SERVERPROPERTY('MachineName') AS ComputerName
		                    , ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS InstanceName
		                    , SERVERPROPERTY('ServerName') AS SqlInstance
		                    , [database] = ''
		                    , [PermState] = 'GRANT'
		                    , [PermissionName] = pb.[permission_name]
		                    , [SecurableType] = pb.class_desc
		                    , [Securable] = @@SERVERNAME
		                    , [Grantee] = spr.name
		                    , [GranteeType] = spr.type_desc
		                    , [revokestatement] = ''
		                    , [grantstatement] = ''
                    FROM sys.server_principals AS spr
                    INNER JOIN sys.fn_builtin_permissions('SERVER') AS pb ON
	                    spr.[name]='bulkadmin' AND pb.[permission_name]='ADMINISTER BULK OPERATIONS'
	                    OR
	                    spr.[name]='dbcreator' AND pb.[permission_name]='CREATE ANY DATABASE'
	                    OR
	                    spr.[name]='diskadmin' AND pb.[permission_name]='ALTER RESOURCES'
	                    OR
	                    spr.[name]='processadmin' AND pb.[permission_name] IN ('ALTER ANY CONNECTION', 'ALTER SERVER STATE')
	                    OR
	                    spr.[name]='sysadmin' AND pb.[permission_name]='CONTROL SERVER'
	                    OR
	                    spr.[name]='securityadmin' AND pb.[permission_name]='ALTER ANY LOGIN'
	                    OR
	                    spr.[name]='serveradmin'  AND pb.[permission_name] IN ('ALTER ANY ENDPOINT', 'ALTER RESOURCES','ALTER SERVER STATE', 'ALTER SETTINGS','SHUTDOWN', 'VIEW SERVER STATE')
	                    OR
	                    spr.[name]='setupadmin' AND pb.[permission_name]='ALTER ANY LINKED SERVER'
                    WHERE spr.[type]='R'
                    ;"

		$DBPermsql = "SELECT SERVERPROPERTY('MachineName') AS ComputerName,
					ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS InstanceName,
					SERVERPROPERTY('ServerName') AS SqlInstance
					, [Database] = DB_NAME()
					, [PermState] = state_desc
					, [PermissionName] = permission_name
					, [SecurableType] = COALESCE(o.type_desc,dp.class_desc)
					, [Securable] = CASE	WHEN class = 0 THEN DB_NAME()
											WHEN class = 1 THEN ISNULL(s.name + '.','')+OBJECT_NAME(major_id)
											WHEN class = 3 THEN SCHEMA_NAME(major_id)
                                            WHEN class = 6 THEN SCHEMA_NAME(t.schema_id)+'.' + t.name
                                            END
					, [Grantee] = USER_NAME(grantee_principal_id)
					, [GranteeType] = pr.type_desc
                    , [revokeStatement] = 'REVOKE ' + permission_name + ' ON ' + isnull(schema_name(o.object_id)+'.','')+OBJECT_NAME(major_id)+ ' FROM [' + USER_NAME(grantee_principal_id) + ']'
                    , [grantStatement] = 'GRANT ' + permission_name + ' ON ' + isnull(schema_name(o.object_id)+'.','')+OBJECT_NAME(major_id)+ ' TO [' + USER_NAME(grantee_principal_id) + ']'
				FROM sys.database_permissions dp
					JOIN sys.database_principals pr ON pr.principal_id = dp.grantee_principal_id
					LEFT OUTER JOIN sys.all_objects o ON o.object_id = dp.major_id
					LEFT OUTER JOIN sys.schemas s ON s.schema_id = o.schema_id
                    LEFT OUTER JOIN sys.types t on t.user_type_id = dp.major_id

				$ExcludeSystemObjectssql

                UNION ALL
                SELECT	  SERVERPROPERTY('MachineName') AS ComputerName
		                , ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS InstanceName
		                , SERVERPROPERTY('ServerName') AS SqlInstance
		                , [database] = DB_NAME()
		                , [PermState] = ''
		                , [PermissionName] = p.[permission_name]
		                , [SecurableType] = p.class_desc
		                , [Securable] = DB_NAME()
		                , [Grantee] = dp.name
		                , [GranteeType] = dp.type_desc
		                , [revokestatement] = ''
		                , [grantstatement] = ''
                FROM sys.database_principals AS dp
                INNER JOIN sys.fn_builtin_permissions('DATABASE') AS p ON
	                dp.[name]='db_accessadmin' AND p.[permission_name] IN ('ALTER ANY USER', 'CREATE SCHEMA')
	                OR
	                dp.[name]='db_backupoperator' AND p.[permission_name] IN ('BACKUP DATABASE', 'BACKUP LOG', 'CHECKPOINT')
	                OR
	                dp.[name] IN ('db_datareader', 'db_denydatareader') AND p.[permission_name]='SELECT'
	                OR
	                dp.[name] IN ('db_datawriter', 'db_denydatawriter') AND p.[permission_name] IN ('INSERT', 'DELETE', 'UPDATE')
	                OR
	                dp.[name]='db_ddladmin' AND
	                p.[permission_name] IN ('ALTER ANY ASSEMBLY', 'ALTER ANY ASYMMETRIC KEY',
							                'ALTER ANY CERTIFICATE', 'ALTER ANY CONTRACT',
							                'ALTER ANY DATABASE DDL TRIGGER', 'ALTER ANY DATABASE EVENT',
							                'NOTIFICATION', 'ALTER ANY DATASPACE', 'ALTER ANY FULLTEXT CATALOG',
							                'ALTER ANY MESSAGE TYPE', 'ALTER ANY REMOTE SERVICE BINDING',
							                'ALTER ANY ROUTE', 'ALTER ANY SCHEMA', 'ALTER ANY SERVICE',
							                'ALTER ANY SYMMETRIC KEY', 'CHECKPOINT', 'CREATE AGGREGATE',
							                'CREATE DEFAULT', 'CREATE FUNCTION', 'CREATE PROCEDURE',
							                'CREATE QUEUE', 'CREATE RULE', 'CREATE SYNONYM', 'CREATE TABLE',
							                'CREATE TYPE', 'CREATE VIEW', 'CREATE XML SCHEMA COLLECTION',
							                'REFERENCES')
	                OR
	                dp.[name]='db_owner' AND p.[permission_name]='CONTROL'
	                OR
	                dp.[name]='db_securityadmin' AND p.[permission_name] IN ('ALTER ANY APPLICATION ROLE', 'ALTER ANY ROLE', 'CREATE SCHEMA', 'VIEW DEFINITION')
 
                WHERE dp.[type]='R'
	                AND dp.is_fixed_role=1
				;"
	}

	process {
		foreach ($instance in $SqlInstance) {
			Write-Message -Level Verbose -Message "Connecting to $instance"
			
			try {
				$server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential -MinimumVersion 9
			}
			catch {
				Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
			}
			
			if ($IncludeServerLevel) {
				Write-Message -Level Debug -Message "T-SQL: $ServPermsql"
				$server.Query($ServPermsql)
			}

			$dbs = $server.Databases

			if ($Database) {
				$dbs = $dbs | Where-Object Name -In $Database
			}

			if ($ExcludeDatabase) {
				$dbs = $dbs | Where-Object Name -NotIn $ExcludeDatabase
			}

			foreach ($db in $dbs) {
				Write-Message -Level Verbose -Message "Processing $db on $instance"

				if ($db.IsAccessible -eq $false) {
					Write-Warning "The database $db is not accessible. Skipping database."
					Continue
				}

				Write-Message -Level Debug -Message "T-SQL: $DBPermsql"
				$db.ExecuteWithResults($DBPermsql).Tables.Rows
			}
		}
	}
}
