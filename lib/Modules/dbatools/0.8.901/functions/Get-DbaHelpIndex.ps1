﻿function Get-DbaHelpIndex
{
<#
.SYNOPSIS
Returns size, row and configuration information for indexes in databases.

.DESCRIPTION
This function will return detailed information on indexes (and optionally statistics) for all indexes in a database, or a given index should one be passed along.
As this uses SQL Server DMVs to access the data it will only work in 2005 and up (sorry folks still running SQL Server 2000).
For performance reasons certain statistics information will not be returned from SQL Server 2005 if an ObjectName is not provided.

The data includes:
	- ObjectName: the table containing the index
	- IndexType: clustered/non-clustered/columnstore and whether the index is unique/primary key
	- KeyColumns: the key columns of the index
	- IncludeColumns: any include columns in the index
	- FilterDefinition: any filter that may have been used in the index 
	- DataCompression: row/page/none depending upon whether or not compression has been used
	- IndexReads: the number of reads of the index since last restart or index rebuild
	- IndexUpdates: the number of writes to the index since last restart or index rebuild
	- SizeKB: the size the index in KB
	- IndexRows: the number of the rows in the index (note filtered indexes will have fewer rows than exist in the table)
	- IndexLookups: the number of lookups that have been performed (only applicable for the heap or clustered index)
	- MostRecentlyUsed: when the index was most recently queried (default to 1900 for when never read)
	- StatsSampleRows: the number of rows queried when the statistics were built/rebuilt (not included in SQL Server 2005 unless ObjectName is specified)
	- StatsRowMods: the number of changes to the statistics since the last rebuild
	- HistogramSteps: the number of steps in the statistics histogram (not included in SQL Server 2005 unless ObjectName is specified)
	- StatsLastUpdated: when the statistics were last rebuilt (not included in SQL Server 2005 unless ObjectName is specified)

.PARAMETER SqlServer
SQLServer name or SMO object representing the SQL Server to connect to.

.PARAMETER SqlCredential
PSCredential object to connect as. If not specified, current Windows login will be used.

.PARAMETER Databases
The database(s) to be connected to for gathering the index information.
	
.PARAMETER ObjectName
The name of a table for which you want to obtain the index information. If the two part naming convention for an object is not used it will use the default schema for the executing user.
	If not passed it will return data on all indexes in a given database.
	
.PARAMETER IncludeStats
This includes statistics as well as indexes in the output (statistics information such as the StatsRowMods will always be returned for indexes).
	
.PARAMETER IncludeDataTypes
This will include the data type of each column that makes up a part of the index definition (key and include columns)
	
.PARAMETER FormatResults
Returns the numerical data in a more user readable format (numerical separator will depend on localization settings).
	

.NOTES 
Original Author: Nic Cain, https://sirsql.net/
dbatools PowerShell module (https://dbatools.io, clemaire@gmail.com)
Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.	

.LINK
https://dbatools.io/Get-DbaHelpIndex

.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Databases MyDB
	Returns information on all indexes on the MyDB database on the localhost.

.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Databases MyDB,MyDB2
	Returns information on all indexes on the MyDB, MyDB2 databases
	
.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Databases MyDB -ObjectName dbo.Table1
	Returns index information on the object dbo.Table1 in the database MyDB
	
.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Databases MyDB -ObjectName dbo.Table1 -IncludeStats
	Returns information on the indexes and statistics for the table dbo.Table1 in the MyDB database
	
.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Database MyDB -ObjectName dbo.Table1 -IncludeDataTypes
	Returns the index information for the table dbo.Table1 in the MyDB database, and includes the data types for the key and include columns
	
.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Database MyDB -ObjectName dbo.Table1 -FormatResults
	Returns the index information for the table dbo.Table1 in the MyDB database, and returns the numerical data with separators to make it more readable (ie 1234 becomes 1,234)
	
.EXAMPLE
Get-DbaHelpIndex -SqlServer localhost -Database MyDB -IncludeStats -FormatResults
	Returns the index information for all index in the MyDB database, as well as statistics, and formats the numerical data to be more redable	
	
#>
	
	[CmdletBinding(SupportsShouldProcess = $false)]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[object[]]$SqlServer,
		[object]$SqlCredential,
		[string]$ObjectName,
		[switch]$IncludeStats,
		[switch]$IncludeDataTypes,
		[switch]$FormatResults
	)
	DynamicParam { if ($SqlServer) { return Get-ParamSqlDatabases -SqlServer $SqlServer -SqlCredential $SqlCredential } }
	
	BEGIN
	{
		
		#Add the table predicate to the query
		IF (!$ObjectName)
		{
			$TablePredicate = "DECLARE @TableName NVARCHAR(256);";
		}
		ELSE
		{
			$TablePredicate = "DECLARE @TableName NVARCHAR(256); SET @TableName = '$ObjectName';";
		}
		
		
		#Figure out if we are including stats in the results
		IF ($IncludeStats)
		{
			$IncludeStatsPredicate = "";
		}
		ELSE
		{
			$IncludeStatsPredicate = "WHERE IndexType != 'STATISTICS'";
		}
		
		#Data types being returns with the results?
		IF ($IncludeDataTypes)
		{
			$IncludeDataTypesPredicate = 'DECLARE @IncludeDataTypes BIT; SET @IncludeDataTypes = 1';
		}
		ELSE
		{
			$IncludeDataTypesPredicate = 'DECLARE @IncludeDataTypes BIT; SET @IncludeDataTypes = 0';
		}
		
#region SizesQuery		
		$SizesQuery = @"
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
		$TablePredicate
		$IncludeDataTypesPredicate
		;

DECLARE @IndexUsageStats TABLE
    (
      object_id INT ,
      index_id INT ,
      user_scans BIGINT ,
      user_seeks BIGINT ,
      user_updates BIGINT ,
      user_lookups BIGINT ,
      last_user_lookup DATETIME2(0) ,
      last_user_scan DATETIME2(0) ,
      last_user_seek DATETIME2(0)
    );

DECLARE @StatsInfo TABLE
    (
      object_id INT ,
      stats_id INT ,
      stats_column_name NVARCHAR(128) ,
      stats_column_id INT ,
      stats_name NVARCHAR(128) ,
      stats_last_updated DATETIME2(0) ,
      stats_sampled_rows BIGINT ,
      rowmods BIGINT ,
      histogramsteps INT ,
      StatsRows BIGINT ,
	  FullObjectName NVARCHAR(256)
    );

INSERT  INTO @IndexUsageStats
        ( object_id ,
          index_id ,
          user_scans ,
          user_seeks ,
          user_updates ,
          user_lookups ,
          last_user_lookup ,
          last_user_scan ,
          last_user_seek
        )
        SELECT  object_id ,
                index_id ,
                user_scans ,
                user_seeks ,
                user_updates ,
                user_lookups ,
                last_user_lookup ,
                last_user_scan ,
                last_user_seek
        FROM    sys.dm_db_index_usage_stats
        WHERE   database_id = DB_ID();

INSERT  INTO @StatsInfo
        ( object_id ,
          stats_id ,
          stats_column_name ,
          stats_column_id ,
          stats_name ,
          stats_last_updated ,
          stats_sampled_rows ,
          rowmods ,
          histogramsteps ,
          StatsRows ,
		  FullObjectName
        )
        SELECT  s.object_id ,
                s.stats_id ,
                c.name ,
                sc.stats_column_id ,
                s.name ,
                sp.last_updated ,
                sp.rows_sampled ,
                sp.modification_counter ,
                sp.steps ,
                sp.rows ,
				QUOTENAME(sch.name) + '.' + QUOTENAME(t.name) AS FullObjectName
        FROM    [sys].[stats] AS [s]
                INNER JOIN sys.stats_columns sc ON s.stats_id = sc.stats_id
                                                   AND s.object_id = sc.object_id
                INNER JOIN sys.columns c ON c.object_id = sc.object_id
                                            AND c.column_id = sc.column_id
                INNER JOIN sys.tables t ON c.object_id = t.object_id
				INNER JOIN sys.schemas sch ON sch.schema_id = t.schema_id
                OUTER APPLY sys.dm_db_stats_properties([s].[object_id],
                                                       [s].[stats_id]) AS [sp]
        WHERE   s.object_id = CASE WHEN @TableName IS NULL THEN s.object_id
                                   ELSE OBJECT_ID(@TableName)
                              END;


;
WITH    cteStatsInfo
          AS ( SELECT   object_id ,
                        si.stats_id ,
                        si.stats_name ,
                        STUFF((SELECT   N', ' + stats_column_name
                               FROM     @StatsInfo si2
                               WHERE    si2.object_id = si.object_id
                                        AND si2.stats_id = si.stats_id
                               ORDER BY si2.stats_column_id
                        FOR   XML PATH(N'') ,
                                  TYPE).value(N'.[1]', N'nvarchar(1000)'), 1,
                              2, N'') AS StatsColumns ,
                        MAX(si.stats_sampled_rows) AS SampleRows ,
                        MAX(si.rowmods) AS RowMods ,
                        MAX(si.histogramsteps) AS HistogramSteps ,
                        MAX(si.stats_last_updated) AS StatsLastUpdated ,
                        MAX(si.StatsRows) AS StatsRows,
						FullObjectName
               FROM     @StatsInfo si
               GROUP BY si.object_id ,
                        si.stats_id ,
                        si.stats_name ,
						si.FullObjectName
             ),
        cteIndexSizes
          AS ( SELECT   object_id ,
                        index_id ,
                        CASE WHEN index_id < 2
                             THEN ( ( SUM(in_row_data_page_count
                                          + lob_used_page_count
                                          + row_overflow_used_page_count)
                                      * 8192 ) / 1024 )
                             ELSE ( ( SUM(used_page_count) * 8192 ) / 1024 )
                        END AS SizeKB
               FROM     sys.dm_db_partition_stats
               GROUP BY object_id ,
                        index_id
             ),
        cteRows
          AS ( SELECT   object_id ,
                        index_id ,
                        SUM(rows) AS IndexRows
               FROM     sys.partitions
               GROUP BY object_id ,
                        index_id
             ),
        cteIndex
          AS ( SELECT   OBJECT_NAME(c.object_id) AS ObjectName ,
                        c.object_id ,
                        c.index_id ,
                        i.name COLLATE SQL_Latin1_General_CP1_CI_AS AS name ,
                        c.index_column_id ,
                        c.column_id ,
                        c.is_included_column ,
                        CASE WHEN @IncludeDataTypes = 0
                                  AND c.is_descending_key = 1
                             THEN sc.name + ' DESC'
                             WHEN @IncludeDataTypes = 0
                                  AND c.is_descending_key = 0 THEN sc.name
                             WHEN @IncludeDataTypes = 1
                                  AND c.is_descending_key = 1
                                  AND c.is_included_column = 0
                             THEN sc.name + ' DESC (' + t.name + ') '
                             WHEN @IncludeDataTypes = 1
                                  AND c.is_descending_key = 0
                                  AND c.is_included_column = 0
                             THEN sc.name + ' (' + t.name + ')'
                             ELSE sc.name
                        END AS ColumnName ,
                        i.filter_definition ,
                        ISNULL(dd.user_scans, 0) AS user_scans ,
                        ISNULL(dd.user_seeks, 0) AS user_seeks ,
                        ISNULL(dd.user_updates, 0) AS user_updates ,
                        ISNULL(dd.user_lookups, 0) AS user_lookups ,
                        CONVERT(DATETIME2(0), ISNULL(dd.last_user_lookup,
                                                     '1901-01-01')) AS LastLookup ,
                        CONVERT(DATETIME2(0), ISNULL(dd.last_user_scan,
                                                     '1901-01-01')) AS LastScan ,
                        CONVERT(DATETIME2(0), ISNULL(dd.last_user_seek,
                                                     '1901-01-01')) AS LastSeek ,
                        i.fill_factor ,
                        c.is_descending_key ,
                        p.data_compression_desc ,
                        i.type_desc ,
                        i.is_unique ,
                        i.is_unique_constraint ,
                        i.is_primary_key ,
                        ci.SizeKB ,
                        cr.IndexRows ,
						QUOTENAME(sch.name) + '.' + QUOTENAME(tbl.name) AS FullObjectName
               FROM     sys.indexes i
                        JOIN sys.index_columns c ON i.object_id = c.object_id
                                                    AND i.index_id = c.index_id
                        JOIN sys.columns sc ON c.object_id = sc.object_id
                                               AND c.column_id = sc.column_id
						INNER JOIN sys.tables tbl ON c.object_id = tbl.object_id
						INNER JOIN sys.schemas sch ON sch.schema_id = tbl.schema_id
                        LEFT JOIN sys.types t ON sc.user_type_id = t.user_type_id
                        LEFT JOIN @IndexUsageStats dd ON i.object_id = dd.object_id
                                                         AND i.index_id = dd.index_id --and dd.database_id = db_id()
                        JOIN sys.partitions p ON i.object_id = p.object_id
                                                 AND i.index_id = p.index_id
                        JOIN cteIndexSizes ci ON i.object_id = ci.object_id
                                                 AND i.index_id = ci.index_id
                        JOIN cteRows cr ON i.object_id = cr.object_id
                                           AND i.index_id = cr.index_id
               WHERE    i.object_id = CASE WHEN @TableName IS NULL
                                           THEN i.object_id
                                           ELSE OBJECT_ID(@TableName)
                                      END
             ),
        cteResults
          AS ( SELECT   ci.FullObjectName ,
                        ci.object_id ,
                        MAX(index_id) AS Index_Id ,
                        ci.type_desc
                        + CASE WHEN ci.is_primary_key = 1
                               THEN ' (PRIMARY KEY)'
                               WHEN ci.is_unique_constraint = 1
                               THEN ' (UNIQUE CONSTRAINT)'
                               WHEN ci.is_unique = 1 THEN ' (UNIQUE)'
                               ELSE ''
                          END AS IndexType ,
                        name AS IndexName ,
                        STUFF((SELECT   N', ' + ColumnName
                               FROM     cteIndex ci2
                               WHERE    ci2.name = ci.name
                                        AND ci2.is_included_column = 0
                               GROUP BY ci2.index_column_id ,
                                        ci2.ColumnName
                               ORDER BY ci2.index_column_id
                        FOR   XML PATH(N'') ,
                                  TYPE).value(N'.[1]', N'nvarchar(1000)'), 1,
                              2, N'') AS KeyColumns ,
                        ISNULL(STUFF((SELECT    N',  ' + ColumnName
                                      FROM      cteIndex ci3
                                      WHERE     ci3.name = ci.name
                                                AND ci3.is_included_column = 1
                                      GROUP BY  ci3.index_column_id ,
                                                ci3.ColumnName
                                      ORDER BY  ci3.index_column_id
                               FOR   XML PATH(N'') ,
                                         TYPE).value(N'.[1]',
                                                     N'nvarchar(1000)'), 1, 2,
                                     N''), '') AS IncludeColumns ,
                        ISNULL(filter_definition, '') AS FilterDefinition ,
                        ci.fill_factor ,
                        CASE WHEN ci.data_compression_desc = 'NONE' THEN ''
                             ELSE ci.data_compression_desc
                        END AS DataCompression ,
                        MAX(ci.user_seeks) + MAX(ci.user_scans)
                        + MAX(ci.user_lookups) AS IndexReads ,
                        MAX(ci.user_lookups) AS IndexLookups ,
                        ci.user_updates AS IndexUpdates ,
                        ci.SizeKB AS SizeKB ,
                        ci.IndexRows AS IndexRows ,
                        CASE WHEN LastScan > LastSeek
                                  AND LastScan > LastLookup THEN LastScan
                             WHEN LastSeek > LastScan
                                  AND LastSeek > LastLookup THEN LastSeek
                             WHEN LastLookup > LastScan
                                  AND LastLookup > LastSeek THEN LastLookup
                             ELSE ''
                        END AS MostRecentlyUsed
               FROM     cteIndex ci
               GROUP BY ci.ObjectName ,
                        ci.name ,
                        ci.filter_definition ,
                        ci.object_id ,
                        ci.LastLookup ,
                        ci.LastSeek ,
                        ci.LastScan ,
                        ci.user_updates ,
                        ci.fill_factor ,
                        ci.data_compression_desc ,
                        ci.type_desc ,
                        ci.is_primary_key ,
                        ci.is_unique ,
                        ci.is_unique_constraint ,
                        ci.SizeKB ,
                        ci.IndexRows ,
						ci.FullObjectName
             ),
        AllResults
          AS ( SELECT   c.FullObjectName ,
                        ISNULL(IndexType, 'STATISTICS') AS IndexType ,
                        ISNULL(IndexName, si.stats_name) AS IndexName ,
                        ISNULL(KeyColumns, si.StatsColumns) AS KeyColumns ,
                        ISNULL(IncludeColumns, '') AS IncludeColumns ,
                        FilterDefinition ,
                        fill_factor AS [FillFactor] ,
                        DataCompression ,
                        IndexReads ,
                        IndexUpdates ,
                        SizeKB ,
                        IndexRows ,
                        IndexLookups ,
                        MostRecentlyUsed ,
                        SampleRows AS StatsSampleRows ,
                        RowMods AS StatsRowMods ,
                        si.HistogramSteps ,
                        si.StatsLastUpdated ,
                        1 AS Ordering
               FROM     cteResults c
                        INNER JOIN cteStatsInfo si ON si.object_id = c.object_id
                                                      AND si.stats_id = c.Index_Id
               UNION
               SELECT   QUOTENAME(sch.name) + '.' + QUOTENAME(tbl.name) AS FullObjectName ,
                        'STATISTICS' ,
                        stats_name ,
                        StatsColumns ,
                        '' ,
                        '' AS FilterDefinition ,
                        '' AS Fill_Factor ,
                        '' AS DataCompression ,
                        '' AS IndexReads ,
                        '' AS IndexUpdates ,
                        '' AS SizeKB ,
                        StatsRows AS IndexRows ,
                        '' AS IndexLookups ,
                        '' AS MostRecentlyUsed ,
                        SampleRows AS StatsSampleRows ,
                        RowMods AS StatsRowMods ,
                        csi.HistogramSteps ,
                        csi.StatsLastUpdated ,
                        2
               FROM     cteStatsInfo csi
			   INNER JOIN sys.tables tbl ON csi.object_id = tbl.object_id
						INNER JOIN sys.schemas sch ON sch.schema_id = tbl.schema_id
               WHERE    stats_id NOT IN (
                        SELECT  stats_id
                        FROM    cteResults c
                                INNER JOIN cteStatsInfo si ON si.object_id = c.object_id
                                                              AND si.stats_id = c.Index_Id )
             )
    SELECT  FullObjectName ,
            ISNULL(IndexType, 'STATISTICS') AS IndexType ,
            IndexName ,
            KeyColumns ,
            ISNULL(IncludeColumns, '') AS IncludeColumns ,
            FilterDefinition ,
            [FillFactor] AS [FillFactor] ,
            DataCompression ,
            IndexReads ,
            IndexUpdates ,
            SizeKB ,
            IndexRows ,
            IndexLookups ,
            MostRecentlyUsed ,
            StatsSampleRows ,
            StatsRowMods ,
            HistogramSteps ,
            StatsLastUpdated
    FROM    AllResults
			$IncludeStatsPredicate
OPTION  ( RECOMPILE );
"@
		#endRegion SizesQuery
		

#region sizesQuery2005
		$SizesQuery2005 = @"
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
		$TablePredicate 
		$IncludeDataTypesPredicate
		;

DECLARE @AllResults TABLE 
	(
		RowNum INT ,
		FullObjectName	NVARCHAR(300) ,
		IndexType	NVARCHAR(256) ,
		IndexName	NVARCHAR(256) ,
		KeyColumns	NVARCHAR(2000) ,
		IncludeColumns	NVARCHAR(2000) ,
		FilterDefinition	NVARCHAR(100) ,
		[FillFactor]	TINYINT ,
		DataCompression	CHAR(4) ,
		IndexReads	BIGINT ,
		IndexUpdates	BIGINT ,
		SizeKB	BIGINT ,
		IndexRows	BIGINT ,
		IndexLookups	BIGINT ,
		MostRecentlyUsed	DATETIME ,
		StatsSampleRows	BIGINT ,
		StatsRowMods	BIGINT ,
		HistogramSteps	INT	,
		StatsLastUpdated	DATETIME ,
		object_id BIGINT ,
		index_id BIGINT
	);

DECLARE @IndexUsageStats TABLE
    (
      object_id INT ,
      index_id INT ,
      user_scans BIGINT ,
      user_seeks BIGINT ,
      user_updates BIGINT ,
      user_lookups BIGINT ,
      last_user_lookup DATETIME ,
      last_user_scan DATETIME ,
      last_user_seek DATETIME
    );

DECLARE @StatsInfo TABLE
    (
      object_id INT ,
      stats_id INT ,
      stats_column_name NVARCHAR(128) ,
      stats_column_id INT ,
      stats_name NVARCHAR(128) ,
      stats_last_updated DATETIME ,
      stats_sampled_rows BIGINT ,
      rowmods BIGINT ,
      histogramsteps INT ,
      StatsRows BIGINT ,
	  FullObjectName NVARCHAR(256)
    );

INSERT  INTO @IndexUsageStats
        ( object_id ,
          index_id ,
          user_scans ,
          user_seeks ,
          user_updates ,
          user_lookups ,
          last_user_lookup ,
          last_user_scan ,
          last_user_seek
        )
        SELECT  object_id ,
                index_id ,
                user_scans ,
                user_seeks ,
                user_updates ,
                user_lookups ,
                last_user_lookup ,
                last_user_scan ,
                last_user_seek
        FROM    sys.dm_db_index_usage_stats
        WHERE   database_id = DB_ID();


INSERT  INTO @StatsInfo
        ( object_id ,
          stats_id ,
          stats_column_name ,
          stats_column_id ,
          stats_name ,
          stats_last_updated ,
          stats_sampled_rows ,
          rowmods ,
          histogramsteps ,
          StatsRows ,
		  FullObjectName
        )
        SELECT  s.object_id ,
                s.stats_id ,
                c.name ,
                sc.stats_column_id ,
                s.name ,
                NULL AS last_updated ,
                NULL AS rows_sampled ,
                NULL AS modification_counter ,
                NULL AS steps ,
                NULL AS rows ,
				QUOTENAME(sch.name) + '.' + QUOTENAME(t.name) AS FullObjectName
        FROM    [sys].[stats] AS [s]
                INNER JOIN sys.stats_columns sc ON s.stats_id = sc.stats_id
                                                   AND s.object_id = sc.object_id
                INNER JOIN sys.columns c ON c.object_id = sc.object_id
                                            AND c.column_id = sc.column_id
                INNER JOIN sys.tables t ON c.object_id = t.object_id
				INNER JOIN sys.schemas sch ON sch.schema_id = t.schema_id
             --   OUTER APPLY sys.dm_db_stats_properties([s].[object_id],
               --                                        [s].[stats_id]) AS [sp]
        WHERE   s.object_id = CASE WHEN @TableName IS NULL THEN s.object_id
                                   ELSE OBJECT_ID(@TableName)
                              END;


;
WITH    cteStatsInfo
          AS ( SELECT   object_id ,
                        si.stats_id ,
                        si.stats_name ,
                        STUFF((SELECT   N', ' + stats_column_name
                               FROM     @StatsInfo si2
                               WHERE    si2.object_id = si.object_id
                                        AND si2.stats_id = si.stats_id
                               ORDER BY si2.stats_column_id
                        FOR   XML PATH(N'') ,
                                  TYPE).value(N'.[1]', N'nvarchar(1000)'), 1,
                              2, N'') AS StatsColumns ,
                        MAX(si.stats_sampled_rows) AS SampleRows ,
                        MAX(si.rowmods) AS RowMods ,
                        MAX(si.histogramsteps) AS HistogramSteps ,
                        MAX(si.stats_last_updated) AS StatsLastUpdated ,
                        MAX(si.StatsRows) AS StatsRows,
						FullObjectName
               FROM     @StatsInfo si
               GROUP BY si.object_id ,
                        si.stats_id ,
                        si.stats_name ,
						si.FullObjectName
             ), 
        cteIndexSizes
          AS ( SELECT   object_id ,
                        index_id ,
                        CASE WHEN index_id < 2
                             THEN ( ( SUM(in_row_data_page_count
                                          + lob_used_page_count
                                          + row_overflow_used_page_count)
                                      * 8192 ) / 1024 )
                             ELSE ( ( SUM(used_page_count) * 8192 ) / 1024 )
                        END AS SizeKB
               FROM     sys.dm_db_partition_stats
               GROUP BY object_id ,
                        index_id
             ),
        cteRows
          AS ( SELECT   object_id ,
                        index_id ,
                        SUM(rows) AS IndexRows
               FROM     sys.partitions
               GROUP BY object_id ,
                        index_id
             ),
        cteIndex
          AS ( SELECT   OBJECT_NAME(c.object_id) AS ObjectName ,
                        c.object_id ,
                        c.index_id ,
                        i.name COLLATE SQL_Latin1_General_CP1_CI_AS AS name ,
                        c.index_column_id ,
                        c.column_id ,
                        c.is_included_column ,
                        CASE WHEN @IncludeDataTypes = 0
                                  AND c.is_descending_key = 1
                             THEN sc.name + ' DESC'
                             WHEN @IncludeDataTypes = 0
                                  AND c.is_descending_key = 0 THEN sc.name
                             WHEN @IncludeDataTypes = 1
                                  AND c.is_descending_key = 1
                                  AND c.is_included_column = 0
                             THEN sc.name + ' DESC (' + t.name + ') '
                             WHEN @IncludeDataTypes = 1
                                  AND c.is_descending_key = 0
                                  AND c.is_included_column = 0
                             THEN sc.name + ' (' + t.name + ')'
                             ELSE sc.name
                        END AS ColumnName ,
                        '' AS filter_definition ,
                        ISNULL(dd.user_scans, 0) AS user_scans ,
                        ISNULL(dd.user_seeks, 0) AS user_seeks ,
                        ISNULL(dd.user_updates, 0) AS user_updates ,
                        ISNULL(dd.user_lookups, 0) AS user_lookups ,
                        CONVERT(DATETIME, ISNULL(dd.last_user_lookup,
                                                     '1901-01-01')) AS LastLookup ,
                        CONVERT(DATETIME, ISNULL(dd.last_user_scan,
                                                     '1901-01-01')) AS LastScan ,
                        CONVERT(DATETIME, ISNULL(dd.last_user_seek,
                                                     '1901-01-01')) AS LastSeek ,
                        i.fill_factor ,
                        c.is_descending_key ,
                        'NONE' as data_compression_desc ,
                        i.type_desc ,
                        i.is_unique ,
                        i.is_unique_constraint ,
                        i.is_primary_key ,
                        ci.SizeKB ,
                        cr.IndexRows ,
						QUOTENAME(sch.name) + '.' + QUOTENAME(tbl.name) AS FullObjectName
               FROM     sys.indexes i
                        JOIN sys.index_columns c ON i.object_id = c.object_id
                                                    AND i.index_id = c.index_id
                        JOIN sys.columns sc ON c.object_id = sc.object_id
                                               AND c.column_id = sc.column_id
						INNER JOIN sys.tables tbl ON c.object_id = tbl.object_id
						INNER JOIN sys.schemas sch ON sch.schema_id = tbl.schema_id
                        LEFT JOIN sys.types t ON sc.user_type_id = t.user_type_id
                        LEFT JOIN @IndexUsageStats dd ON i.object_id = dd.object_id
                                                         AND i.index_id = dd.index_id --and dd.database_id = db_id()
                        JOIN sys.partitions p ON i.object_id = p.object_id
                                                 AND i.index_id = p.index_id
                        JOIN cteIndexSizes ci ON i.object_id = ci.object_id
                                                 AND i.index_id = ci.index_id
                        JOIN cteRows cr ON i.object_id = cr.object_id
                                           AND i.index_id = cr.index_id
               WHERE    i.object_id = CASE WHEN @TableName IS NULL
                                           THEN i.object_id
                                           ELSE OBJECT_ID(@TableName)
                                      END
             ),
        cteResults
          AS ( SELECT   ci.FullObjectName ,
                        ci.object_id ,
                        MAX(index_id) AS Index_Id ,
                        ci.type_desc
                        + CASE WHEN ci.is_primary_key = 1
                               THEN ' (PRIMARY KEY)'
                               WHEN ci.is_unique_constraint = 1
                               THEN ' (UNIQUE CONSTRAINT)'
                               WHEN ci.is_unique = 1 THEN ' (UNIQUE)'
                               ELSE ''
                          END AS IndexType ,
                        name AS IndexName ,
                        STUFF((SELECT   N', ' + ColumnName
                               FROM     cteIndex ci2
                               WHERE    ci2.name = ci.name
                                        AND ci2.is_included_column = 0
                               GROUP BY ci2.index_column_id ,
                                        ci2.ColumnName
                               ORDER BY ci2.index_column_id
                        FOR   XML PATH(N'') ,
                                  TYPE).value(N'.[1]', N'nvarchar(1000)'), 1,
                              2, N'') AS KeyColumns ,
                        ISNULL(STUFF((SELECT    N',  ' + ColumnName
                                      FROM      cteIndex ci3
                                      WHERE     ci3.name = ci.name
                                                AND ci3.is_included_column = 1
                                      GROUP BY  ci3.index_column_id ,
                                                ci3.ColumnName
                                      ORDER BY  ci3.index_column_id
                               FOR   XML PATH(N'') ,
                                         TYPE).value(N'.[1]',
                                                     N'nvarchar(1000)'), 1, 2,
                                     N''), '') AS IncludeColumns ,
                        ISNULL(filter_definition, '') AS FilterDefinition ,
                        ci.fill_factor ,
                        CASE WHEN ci.data_compression_desc = 'NONE' THEN ''
                             ELSE ci.data_compression_desc
                        END AS DataCompression ,
                        MAX(ci.user_seeks) + MAX(ci.user_scans)
                        + MAX(ci.user_lookups) AS IndexReads ,
                        MAX(ci.user_lookups) AS IndexLookups ,
                        ci.user_updates AS IndexUpdates ,
                        ci.SizeKB AS SizeKB ,
                        ci.IndexRows AS IndexRows ,
                        CASE WHEN LastScan > LastSeek
                                  AND LastScan > LastLookup THEN LastScan
                             WHEN LastSeek > LastScan
                                  AND LastSeek > LastLookup THEN LastSeek
                             WHEN LastLookup > LastScan
                                  AND LastLookup > LastSeek THEN LastLookup
                             ELSE ''
                        END AS MostRecentlyUsed
               FROM     cteIndex ci
               GROUP BY ci.ObjectName ,
                        ci.name ,
                        ci.filter_definition ,
                        ci.object_id ,
                        ci.LastLookup ,
                        ci.LastSeek ,
                        ci.LastScan ,
                        ci.user_updates ,
                        ci.fill_factor ,
                        ci.data_compression_desc ,
                        ci.type_desc ,
                        ci.is_primary_key ,
                        ci.is_unique ,
                        ci.is_unique_constraint ,
                        ci.SizeKB ,
                        ci.IndexRows ,
						ci.FullObjectName
             ), AllResults AS 
				(		 SELECT   c.FullObjectName ,
                        ISNULL(IndexType, 'STATISTICS') AS IndexType ,
                        ISNULL(IndexName, '') AS IndexName ,
                        ISNULL(KeyColumns, '') AS KeyColumns ,
                        ISNULL(IncludeColumns, '') AS IncludeColumns ,
                        FilterDefinition ,
                        fill_factor AS [FillFactor] ,
                        DataCompression ,
                        IndexReads ,
                        IndexUpdates ,
                        SizeKB ,
                        IndexRows ,
                        IndexLookups ,
                        MostRecentlyUsed ,
                        NULL AS StatsSampleRows ,
                        NULL AS StatsRowMods ,
                        NULL AS HistogramSteps ,
                        NULL AS StatsLastUpdated ,
                        1 AS Ordering ,
						c.object_id ,
						c.Index_Id
               FROM     cteResults c
                        INNER JOIN cteStatsInfo si ON si.object_id = c.object_id
                                                      AND si.stats_id = c.Index_Id
				UNION
               SELECT   QUOTENAME(sch.name) + '.' + QUOTENAME(tbl.name) AS FullObjectName ,
                        'STATISTICS' ,
                        stats_name ,
                        StatsColumns ,
                        '' ,
                        '' AS FilterDefinition ,
                        '' AS Fill_Factor ,
                        '' AS DataCompression ,
                        '' AS IndexReads ,
                        '' AS IndexUpdates ,
                        '' AS SizeKB ,
                        StatsRows AS IndexRows ,
                        '' AS IndexLookups ,
                        '' AS MostRecentlyUsed ,
                        SampleRows AS StatsSampleRows ,
                        RowMods AS StatsRowMods ,
                        csi.HistogramSteps ,
                        csi.StatsLastUpdated ,
                        2 ,
						csi.object_id ,
						csi.stats_id
               FROM     cteStatsInfo csi
			   INNER JOIN sys.tables tbl ON csi.object_id = tbl.object_id
						INNER JOIN sys.schemas sch ON sch.schema_id = tbl.schema_id
						LEFT JOIN (SELECT si.object_id, si.stats_id
									FROM    cteResults c
									INNER JOIN cteStatsInfo si ON si.object_id = c.object_id
                                                              AND si.stats_id = c.Index_Id ) AS x on csi.object_id = x.object_id and csi.stats_id = x.stats_id
				WHERE x.object_id is null
             )
    INSERT INTO @AllResults
	SELECT  row_number() OVER (ORDER BY FullObjectName) AS RowNum ,
			FullObjectName ,
            ISNULL(IndexType, 'STATISTICS') AS IndexType ,
            IndexName ,
            KeyColumns ,
            ISNULL(IncludeColumns, '') AS IncludeColumns ,
            FilterDefinition ,
            [FillFactor] AS [FillFactor] ,
            DataCompression ,
            IndexReads ,
            IndexUpdates ,
            SizeKB ,
            IndexRows ,
            IndexLookups ,
            MostRecentlyUsed ,
            StatsSampleRows ,
            StatsRowMods ,
            HistogramSteps ,
            StatsLastUpdated ,
			object_id ,
			index_id
    FROM    AllResults
			$IncludeStatsPredicate
OPTION  ( RECOMPILE );

/* Only update the stats data on 2005 for a single table, otherwise the run time for this is a potential problem for large table/index volumes */
IF @TableName IS NOT NULL
BEGIN

	DECLARE @StatsInfo2005 TABLE (Name nvarchar(128), Updated DATETIME, Rows BIGINT, RowsSampled BIGINT, Steps INT, Density INT, AverageKeyLength INT, StringIndex NVARCHAR(20))

	DECLARE @SqlCall NVARCHAR(2000), @RowNum INT;
	SELECT @RowNum = min(RowNum) FROM @AllResults;
	WHILE @RowNum IS NOT NULL
	BEGIN
		SELECT @SqlCall = 'dbcc show_statistics("'+FullObjectName+'", "'+IndexName+'") with stat_header' FROM @AllResults WHERE RowNum = @RowNum;
		INSERT INTO @StatsInfo2005 exec (@SqlCall);
		UPDATE @AllResults
			SET StatsSampleRows = RowsSampled,
			HistogramSteps = Steps,
			StatsLastUpdated = Updated
			FROM @StatsInfo2005
			WHERE RowNum = @RowNum;
		DELETE FROM @StatsInfo2005
		SELECT @RowNum = min(RowNum) FROM @AllResults WHERE RowNum > @RowNum;
	END;

END;

UPDATE a
SET a.StatsRowMods = i.rowmodctr
FROM @AllResults a
	JOIN sys.sysindexes i ON a.object_id = i.id AND a.index_id = i.indid;

SELECT	FullObjectName ,
		IndexType ,
		IndexName ,
		KeyColumns ,
		IncludeColumns ,
		FilterDefinition ,
		[FillFactor] ,
		DataCompression ,
		IndexReads ,
		IndexUpdates ,
		SizeKB ,
		IndexRows ,
		IndexLookups ,
		MostRecentlyUsed ,
		StatsSampleRows ,
		StatsRowMods ,
		HistogramSteps	,
		StatsLastUpdated
FROM @AllResults;

"@

#endregion sizesQuery2005
		$server = Connect-DbaSqlServer -SqlServer $SqlServer -SqlCredential $SqlCredential
	}
	
	PROCESS
	{

        #Need to check the version of SQL
        if ($server.versionMajor -ge 10)
        {
            $indexesQuery = $SizesQuery
        }	

        elseif ($server.Information.Version.Major -eq 9)
        {
            $indexesQuery = $SizesQuery2005
        }

        else 
        {
			Write-Warning "This function does not support versions lower than SQL Server 2005 (v9)"
			continue
        }

		# Convert from RuntimeDefinedParameter object to regular array
		$databases = $psboundparameters.Databases
		
		if ($pipedatabase.Length -gt 0)
		{
			$Source = $pipedatabase[0].parent.name
			$databases = $pipedatabase.name
		}
		
		if ($databases.Count -eq 0)
		{
			$databases = ($server.Databases | Where-Object { $_.Status -ne "Offline" }).Name
		}
		
		if ($databases.Count -gt 0)
		{
			foreach ($db in $databases)
			{
				try
				{
                    $IndexDetails = ($server.Databases[$db].ExecuteWithResults($indexesQuery)).Tables[0];
			
					if ($FormatResults)
					{
						foreach ($detail in $IndexDetails)
						{
							$recentlyused = [datetime]$detail.MostRecentlyUsed
							
							if ($recentlyused.year -eq 1900)
							{
								$recentlyused = $null
							}
							
							[pscustomobject]@{
								DatabaseName = $db
								ObjectName = $detail.FullObjectName
								IndexType = $detail.IndexType
								KeyColumns = $detail.KeyColumns
								IncludeColumns = $detail.IncludeColumns
								FilterDefinition = $detail.FilterDefinition
								DataCompression = $detail.DataCompression
								IndexReads = "{0:N0}" -f $detail.IndexReads
								IndexUpdates = "{0:N0}" -f $detail.IndexUpdates
								SizeKB = "{0:N0}" -f $detail.SizeKB
								IndexRows = "{0:N0}" -f $detail.IndexRows
								IndexLookups = "{0:N0}" -f $detail.IndexLookups
								MostRecentlyUsed = $recentlyused
								StatsSampleRows = "{0:N0}" -f $detail.StatsSampleRows
								StatsRowMods = "{0:N0}" -f $detail.StatsRowMods
								HistogramSteps = $detail.HistogramSteps
								StatsLastUpdated = $detail.StatsLastUpdated
							}
						}
					}
					
					else
					{
						foreach ($detail in $IndexDetails)
						{
							$recentlyused = [datetime]$detail.MostRecentlyUsed
							
							if ($recentlyused.year -eq 1900)
							{
								$recentlyused = $null
							}
							
							[pscustomobject]@{
								DatabaseName = $db
								ObjectName = $detail.FullObjectName
								IndexType = $detail.IndexType
								KeyColumns = $detail.KeyColumns
								IncludeColumns = $detail.IncludeColumns
								FilterDefinition = $detail.FilterDefinition
								DataCompression = $detail.DataCompression
								IndexReads = $detail.IndexReads
								IndexUpdates = $detail.IndexUpdates
								SizeKB = $detail.SizeKB
								IndexRows = $detail.IndexRows
								IndexLookups = $detail.IndexLookups
								MostRecentlyUsed = $recentlyused
								StatsSampleRows = $detail.StatsSampleRows
								StatsRowMods = $detail.StatsRowMods
								HistogramSteps = $detail.HistogramSteps
								StatsLastUpdated = $detail.StatsLastUpdated
							}
						}
					}
					
					
				}
				catch
				{
					Write-Warning "Cannot process $db on $server"
				}
			}
			
		}
	}
	
}