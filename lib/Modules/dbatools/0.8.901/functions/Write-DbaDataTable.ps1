﻿Function Write-DbaDataTable
{
<#
.SYNOPSIS
Writes data to a SQL Server Table

.DESCRIPTION
Writes a .NET DataTable to a SQL Server table using SQL Bulk Copy

.PARAMETER SqlServer
The SQL Server that you're connecting to.

.PARAMETER SqlCredential
Credential object used to connect to the SQL Server as a different user be it Windows or SQL Server. Windows users are determiend by the existence of a backslash, so if you are intending to use an alternative Windows connection instead of a SQL login, ensure it contains a backslash.

.PARAMETER InputObject
This is the DataTable (or datarow) to import to SQL Server.
	
.PARAMETER Table
The table name. You can specify a one, two, or three part table name. If you specify a one or two part name, you must also use -Database.
	
If the table does not exist, you can use AutoCreateTable to automatically create the table with inefficient data types.
	
.PARAMETER Schema
Defaults to dbo if no schema is specified.

.PARAMETER AutoCreateTable
Automatically create the table if it doesn't exist. Note that the table will be created with inefficient data types such as nvarchar(max).

.PARAMETER NoTableLock
By default, a TableLock is placed on the destination table. Use this parameter to remove the lock.
	
.PARAMETER NotifyAfter
Sets the option to show the notification after so many rows of import

.PARAMETER BatchSize
The batchsize for the import defaults to 5000.

.PARAMETER TableLock
SqlBulkCopy option. Per Microsoft "Obtain a bulk update lock for the duration of the bulk copy operation. When not 
specified, row locks are used." TableLock is automatically used when Turbo is specified.
		
.PARAMETER CheckConstraints
SqlBulkCopy option. Per Microsoft "Check constraints while data is being inserted. By default, constraints are not checked."

.PARAMETER FireTriggers
SqlBulkCopy option. Per Microsoft "When specified, cause the server to fire the insert triggers for the rows being inserted into the database."

.PARAMETER KeepIdentity
SqlBulkCopy option. Per Microsoft "Preserve source identity values. When not specified, identity values are assigned by the destination."

.PARAMETER KeepNulls
SqlBulkCopy option. Per Microsoft "Preserve null values in the destination table regardless of the settings for default values. When not specified, null values are replaced by default values where applicable."
	
.PARAMETER Truncate
Prompts for confirmation then truncates destination 

.PARAMETER Confirm
Can disable prompt for confirmation by using -Confirm:$false

.PARAMETER WhatIf
Shows what would happen if the command were executed 

.NOTES
dbatools PowerShell module (https://dbatools.io)
Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

.LINK
 https://dbatools.io/Write-DbaDataTable

.EXAMPLE
$datatable = Import-Csv C:\temp\customers.csv | Out-DbaDataTable
Write-DbaDataTable -SqlServer sql2014 -InputObject $datatable -Table mydb.dbo.customers

Quickly and efficiently performs a bulk insert of all the data in customers.csv into database: mydb, schema: dbo, table: customers
Shows progress as rows are inserted. If table does not exist, import is halted.
	
.EXAMPLE
$datatable = Import-Csv C:\temp\customers.csv | Out-DbaDataTable
$datatable | Write-DbaDataTable -SqlServer sql2014 -Table mydb.dbo.customers

Performs row by row insert. Super slow. No progress bar. Don't do this. Use -InputObject instead.
	
.EXAMPLE
$datatable = Import-Csv C:\temp\customers.csv | Out-DbaDataTable
Write-DbaDataTable -SqlServer sql2014 -InputObject $datatable -Table mydb.dbo.customers -AutoCreateTable

Quickly and efficiently performs a bulk insert of all the data. If mydb.dbo.customers does not exist, it will be created with inefficient but forgiving datatypes.
	
.EXAMPLE
$datatable = Import-Csv C:\temp\customers.csv | Out-DbaDataTable
Write-DbaDataTable -SqlServer sql2014 -InputObject $datatable -Table mydb.dbo.customers -Truncate

Quickly and efficiently performs a bulk insert of all the data. Prompts to confirm that truncating mydb.dbo.customers prior to import is desired.
Prompts again to perform the import. Answer A for Yes to All.
		
.EXAMPLE
$datatable = Import-Csv C:\temp\customers.csv | Out-DbaDataTable
Write-DbaDataTable -SqlServer sql2014 -InputObject $datatable -Database mydb -Table customers -KeepNulls

Quickly and efficiently performs a bulk insert of all the data into mydb.dbo.customers -- since Schema was not specified, dbo was used.
	
Per Microsoft, KeepNulls will "Preserve null values in the destination table regardless of the settings for default values. When not specified, null values are replaced by default values where applicable."
	
#>	
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
	param (
		[Parameter(Mandatory = $true)]
		[object]$SqlServer,
		[Alias("Credential")]
		[System.Management.Automation.PSCredential]$SqlCredential,
		[Parameter(ValueFromPipeline = $true)]
		[Alias("DataTable")]
		[object]$InputObject,
		[string]$Schema = 'dbo',
		[Parameter(Mandatory = $true)]
		[string]$Table,
		[int]$BatchSize = 50000,
		[int]$NotifyAfter = 5000,
		[switch]$NoTableLock,
		[switch]$CheckConstraints,
		[switch]$FireTriggers,
		[switch]$KeepIdentity,
		[switch]$KeepNulls,
		[switch]$Truncate,
		[switch]$AutoCreateTable
	)
	
	DynamicParam { if ($sqlserver) { return Get-ParamSqlDatabase -SqlServer $SqlServer -SqlCredential $SqlCredential } }
	
	BEGIN
	{
		if (!$Truncate) { $ConfirmPreference = "None" }
		
		# Getting the total rows copied is a challenge. Use SqlBulkCopyExtension.
		# http://stackoverflow.com/questions/1188384/sqlbulkcopy-row-count-when-complete
		
		$source = 'namespace System.Data.SqlClient
		{    
			using Reflection;

			public static class SqlBulkCopyExtension
			{
				const String _rowsCopiedFieldName = "_rowsCopied";
				static FieldInfo _rowsCopiedField = null;

				public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
				{
					if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);            
					return (int)_rowsCopiedField.GetValue(bulkCopy);
				}
			}
		}'
		
		Add-Type -ReferencedAssemblies 'System.Data.dll' -TypeDefinition $source -ErrorAction SilentlyContinue
		
		$database = $psboundparameters.Database
		$dotcount = ([regex]::Matches($table, "\.")).count
		
		if ($dotcount -lt 2 -and $database -eq $null)
		{
			Write-Warning "You must specify a database or fully qualififed table name"
			Continue
		}
		
		if ($dotcount -eq 1)
		{
			$schema = $Table.Split(".")[0]
			$table = $Table.Split(".")[1]
		}
		
		if ($dotcount -eq 2)
		{
			$database = $Table.Split(".")[0]
			$schema = $Table.Split(".")[1]
			$table = $Table.Split(".")[2]
		}
		
		$fqtn = "[$database].[$Schema].[$table]"
		
		$server = Connect-SqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
		
		$db = $server.Databases | Where-Object { $_.Name -eq $database }
		
		if ($db -eq $null)
		{
			Write-Warning "$database does not exist"
			continue
		}
		
		$bulkCopyOptions = @()
		$options = "TableLock", "CheckConstraints", "FireTriggers", "KeepIdentity", "KeepNulls", "Default", "Truncate"
		
		foreach ($option in $options)
		{
			$optionValue = Get-Variable $option -ValueOnly -ErrorAction SilentlyContinue
			if ($optionValue -eq $true) { $bulkCopyOptions += "$option" }
		}
		
		$bulkCopyOptions = $bulkCopyOptions -join " & "
		
		if ($truncate -eq $true)
		{
			if ($Pscmdlet.ShouldProcess($SqlServer, "Truncating $fqtn"))
			{
				try
				{
					Write-Output "Truncating $fqtn"
					$null = $server.Databases[$database].ExecuteNonQuery("TRUNCATE TABLE $fqtn")
				}
				catch
				{
					Write-Warning "Could not truncate $fqtn. Table may not exist or may have key constraints."
				}
			}
		}
		
		$tablelock = $NoTableLock -eq $false
		
		if ($InputObject -eq $null)
		{
			Write-Warning "Using the pipeline can be insanely (5 minutes vs 0.5 seconds) slower for larger batches and doesn't show a progress bar. Consider using -InputObject for large batches."
		}
		
		$bulkcopy = New-Object Data.SqlClient.SqlBulkCopy($server.ConnectionContext.ConnectionString) #, $bulkCopyOptions)
		$bulkcopy.DestinationTableName = $fqtn
		$bulkcopy.BatchSize = $batchsize
		$bulkcopy.NotifyAfter = $NotifyAfter
		
		$elapsed = [System.Diagnostics.Stopwatch]::StartNew()
		# Add rowcount output
		$bulkCopy.Add_SqlRowscopied({
				$script:totalrows = $args[1].RowsCopied
				$percent = [int](($script:totalrows/$rowcount) * 100)
				$timetaken = [math]::Round($elapsed.Elapsed.TotalSeconds, 1)
				Write-Progress -id 1 -activity "Inserting $rowcount rows" -percentcomplete $percent -status ([System.String]::Format("Progress: {0} rows ({1}%) in {2} seconds", $script:totalrows, $percent, $timetaken))
			})
	}
	
	PROCESS
	{
		if ($InputObject -eq $null)
		{
			Write-Warning "Input object is null"
			break
		}
		
		$validtypes = @([System.Data.DataSet], [System.Data.DataTable], [System.Data.DataRow], [System.Data.DataRow[]]) #[System.Data.Common.DbDataReader], [System.Data.IDataReader]
		
		if ($InputObject.GetType() -notin $validtypes)
		{
			Write-Warning "Data is not of the right type (DbDataReader, DataTable, DataRow, or IDataReader)."
			break
		}
		
		If ($InputObject.GetType() -eq [System.Data.DataSet])
		{
			if ($InputObject.Tables -ne $null) { $InputObject = $InputObject.Tables }
		}
		
		$db.tables.refresh()
		$tableExists = $db | Where-Object { $_.Tables.Name -eq $table -and $_.Tables.Schema -eq $schema }
		
		if ($tableExists -eq $null)
		{
			if ($AutoCreateTable -eq $false)
			{
				Write-Warning "$fqtn does not exist. Use -AutoCreateTable to AutoCreate."
				break
			}
			else
			{
				if ($schema -notin $server.Databases[0].Schemas.Name)
				{
					Write-Warning "Schema does not exist"
					break
				}
				
				# Get SQL datatypes by best guess on first data row
				$sqldatatypes = @(); $index = -1
				$columns = $InputObject.Columns
				
				if ($columns -eq $null) { $columns = $InputObject.Table.Columns }
				
				foreach ($column in $columns)
				{
					$sqlcolumnname = $column.ColumnName
					
					try
					{
						$columnvalue = $InputObject.Rows[0].$sqlcolumnname
					}
					catch
					{
						$columnvalue = $InputObject.$sqlcolumnname
					}
					
					if ($columnvalue -eq $null)
					{
						$columnvalue = $InputObject.$sqlcolumnname
					}
					
					# bigint, float, and datetime are more accurate, but it didn't work
					# as often as it should have, so we'll just go for a smaller datatype
					
					# also, if anyone wants to add support for using the datatable datatypes
					# to make the table creation more accurate, please do
					
					if ([int64]::TryParse($columnvalue, [ref]0) -eq $true)
					{
						$sqldatatype = "varchar(50)"
					}
					elseif ([double]::TryParse($columnvalue, [ref]0) -eq $true)
					{
						$sqldatatype = "varchar(50)"
					}
					elseif ([datetime]::TryParse($columnvalue, [ref]0) -eq $true)
					{
						$sqldatatype = "varchar(50)"
					}
					else
					{
						$sqldatatype = "varchar(MAX)"
					}
					
					$sqldatatypes += "[$sqlcolumnname] $sqldatatype"
				}
				
				$sql = "BEGIN CREATE TABLE $fqtn ($($sqldatatypes -join ' NULL,')) END"
				
				Write-Debug $sql
				
				if ($Pscmdlet.ShouldProcess($SqlServer, "Creating table $fqtn"))
				{
					try
					{
						$null = $server.Databases[$database].ExecuteNonQuery($sql)
					}
					catch
					{
						Write-Warning "The following query failed: $sql"
						return
					}
				}
			}
		}
		
		$rowcount = $InputObject.Rows.count
		if ($rowcount -eq 0) { $rowcount = 1 }
		
		if ($Pscmdlet.ShouldProcess($SqlServer, "Writing $rowcount rows to $fqtn"))
		{
			$bulkCopy.WriteToServer($InputObject)
			if ($rowcount -is [int]) { Write-Progress -id 1 -activity "Inserting $rowcount rows" -status "Complete" -Completed }
		}
	}
	END
	{
		if ($bulkcopy)
		{
			$bulkcopy.Close()
			$bulkcopy.Dispose()
		}
	}
}
		