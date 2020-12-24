-- Фрагментация индесов 
SELECT *
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL)
       WHERE avg_fragmentation_in_percent > 0;

-- Генерация команд для фрагментированных индексов при помощи курсора
DECLARE @SQL NVARCHAR(MAX)
DECLARE cur CURSOR LOCAL READ_ONLY FORWARD_ONLY FOR
SELECT '
ALTER INDEX [' + i.name + N'] ON [' + SCHEMA_NAME(o.[schema_id]) + '].[' + o.name + '] ' + 		CASE WHEN s.avg_fragmentation_in_percent > 30
	THEN 'REBUILD WITH (SORT_IN_TEMPDB = ON)'
	ELSE 'REORGANIZE'
END + ';'
FROM (
SELECT 
		s.[object_id]
	, s.index_id
	, avg_fragmentation_in_percent = MAX(s.avg_fragmentation_in_percent)
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) s
WHERE s.page_count > 128 -- > 1 MB
	AND s.index_id > 0 -- <> HEAP
	AND s.avg_fragmentation_in_percent > 5
GROUP BY s.[object_id], s.index_id
) s
JOIN sys.indexes i WITH(NOLOCK) ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
JOIN sys.objects o WITH(NOLOCK) ON o.[object_id] = s.[object_id]
OPEN cur
FETCH NEXT FROM cur INTO @SQL
WHILE @@FETCH_STATUS = 0 BEGIN
EXEC sys.sp_executesql @SQL
	

FETCH NEXT FROM cur INTO @SQL	
END 
CLOSE cur 
DEALLOCATE cur

--Генерация команд для фрагментированных индексов без использования курсора
DECLARE
@PageCount INT = 128
, @RebuildPercent INT = 30
, @ReorganizePercent INT = 10
, @IsOnlineRebuild BIT = 0
, @IsVersion2012Plus BIT =
CASE WHEN CAST(SERVERPROPERTY('productversion') AS CHAR(2)) NOT IN ('8.', '9.', '10')
THEN 1
ELSE 0
END
, @IsEntEdition BIT =
CASE WHEN SERVERPROPERTY('EditionID') IN (1804890536, -2117995310)
THEN 1
ELSE 0
END
,@SQL NVARCHAR(MAX)
SELECT @SQL = (
SELECT
'
ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(s2.name) + '.' + QUOTENAME(o.name) + ' ' +
CASE WHEN s.avg_fragmentation_in_percent >= @RebuildPercent
THEN 'REBUILD'
ELSE 'REORGANIZE'
END + ' PARTITION = ' +
CASE WHEN ds.[type] != 'PS'
THEN 'ALL'
ELSE CAST(s.partition_number AS NVARCHAR(10))
END + ' WITH (' + 
CASE WHEN s.avg_fragmentation_in_percent >= @RebuildPercent
THEN 'SORT_IN_TEMPDB = ON' + 
    CASE WHEN @IsEntEdition = 1
            AND @IsOnlineRebuild = 1 
            AND ISNULL(lob.is_lob_legacy, 0) = 0
            AND (
                    ISNULL(lob.is_lob, 0) = 0
                OR
                    (lob.is_lob = 1 AND @IsVersion2012Plus = 1)
            )
        THEN ', ONLINE = ON'
        ELSE ''
    END
ELSE 'LOB_COMPACTION = ON'
END + ')'
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) s
JOIN sys.indexes i ON i.[object_id] = s.[object_id] AND i.index_id = s.index_id
LEFT JOIN (
SELECT
    c.[object_id]
, index_id = ISNULL(i.index_id, 1)
, is_lob_legacy = MAX(CASE WHEN c.system_type_id IN (34, 35, 99) THEN 1 END)
, is_lob = MAX(CASE WHEN c.max_length = -1 THEN 1 END)
FROM sys.columns c
LEFT JOIN sys.index_columns i ON c.[object_id] = i.[object_id]
AND c.column_id = i.column_id AND i.index_id > 0
WHERE c.system_type_id IN (34, 35, 99)
OR c.max_length = -1
GROUP BY c.[object_id], i.index_id
) lob ON lob.[object_id] = i.[object_id] AND lob.index_id = i.index_id
JOIN sys.objects o ON o.[object_id] = i.[object_id]
JOIN sys.schemas s2 ON o.[schema_id] = s2.[schema_id]
JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id
WHERE i.[type] IN (1, 2)
AND i.is_disabled = 0
AND i.is_hypothetical = 0
AND s.index_level = 0
AND s.page_count > @PageCount
AND s.alloc_unit_type_desc = 'IN_ROW_DATA'
AND o.[type] IN ('U', 'V')
AND s.avg_fragmentation_in_percent > @ReorganizePercent
FOR XML PATH(''), TYPE
).value('.', 'NVARCHAR(MAX)')
PRINT @SQL
EXEC sys.sp_executesql @SQL

--Просмотр статистики
SELECT s.*
FROM sys.stats s
JOIN sys.objects o ON s.[object_id] = o.[object_id]
WHERE o.is_ms_shipped = 0


--Автообновление статистики
DECLARE @DateNow DATETIME
SELECT @DateNow = DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE()))
DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL = (	
    SELECT '
	UPDATE STATISTICS [' + SCHEMA_NAME(o.[schema_id]) + '].[' + o.name + '] [' + s.name + ']
		WITH FULLSCAN' + CASE WHEN s.no_recompute = 1 THEN ', NORECOMPUTE' ELSE '' END + ';'
	FROM sys.stats s WITH(NOLOCK)
	JOIN sys.objects o WITH(NOLOCK) ON s.[object_id] = o.[object_id]
	WHERE o.[type] IN ('U', 'V')
		AND o.is_ms_shipped = 0
		AND ISNULL(STATS_DATE(s.[object_id], s.stats_id), GETDATE()) <= @DateNow
    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
PRINT @SQL
EXEC sys.sp_executesql @SQL


--Менее частое обновление статистики для больших таблиц
DECLARE @DateNow DATETIME
SELECT @DateNow = DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE()))
DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL = (
    SELECT '
	UPDATE STATISTICS [' + SCHEMA_NAME(o.[schema_id]) + '].[' + o.name + '] [' + s.name + ']
		WITH FULLSCAN' + CASE WHEN s.no_recompute = 1 THEN ', NORECOMPUTE' ELSE '' END + ';'
	FROM (
		SELECT 
			  [object_id]
			, name
			, stats_id
			, no_recompute
			, last_update = STATS_DATE([object_id], stats_id)
		FROM sys.stats WITH(NOLOCK)
		WHERE auto_created = 0
			AND is_temporary = 0 -- 2012+
	) s
	JOIN sys.objects o WITH(NOLOCK) ON s.[object_id] = o.[object_id]
	JOIN (
		SELECT
			  p.[object_id]
			, p.index_id
			, total_pages = SUM(a.total_pages)
		FROM sys.partitions p WITH(NOLOCK)
		JOIN sys.allocation_units a WITH(NOLOCK) ON p.[partition_id] = a.container_id
		GROUP BY 
			  p.[object_id]
			, p.index_id
	) p ON o.[object_id] = p.[object_id] AND p.index_id = s.stats_id
	WHERE o.[type] IN ('U', 'V')
		AND o.is_ms_shipped = 0
		AND (
			  last_update IS NULL AND p.total_pages > 0 -- never updated and contains rows
			OR
			  last_update <= DATEADD(dd, 
				CASE WHEN p.total_pages > 4096 -- > 4 MB
					THEN -2 -- updated 3 days ago
					ELSE 0 
				END, @DateNow)
		)
    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
PRINT @SQL
EXEC sys.sp_executesql @SQL

--Создание таблицы для записи сообщений об ошибках во время бэкапов
USE [master]
GO
IF OBJECT_ID('dbo.BackupError', 'U') IS NOT NULL
    DROP TABLE dbo.BackupError
GO
CREATE TABLE dbo.BackupError (
    db SYSNAME PRIMARY KEY,
    dt DATETIME NOT NULL DEFAULT GETDATE(),
    msg NVARCHAR(2048)
)
GO

--Резервирование всех баз
USE [master]
GO
SET NOCOUNT ON
TRUNCATE TABLE dbo.BackupError
DECLARE
      @db SYSNAME
    , @sql NVARCHAR(MAX)
    , @can_compress BIT
    , @path NVARCHAR(4000)
    , @name SYSNAME
    , @include_time BIT
--SET @path = '\\pub\backup' -- можно задать свой путь для бекапа
IF @path IS NULL -- либо писать в папку для бекапов указанную по умолчанию
    EXEC [master].dbo.xp_instance_regread
            N'HKEY_LOCAL_MACHINE',
            N'Software\Microsoft\MSSQLServer\MSSQLServer',
            N'BackupDirectory', @path OUTPUT, 'no_output'
SET @can_compress = ISNULL(CAST(( -- вопросы сжатия обсуждаются ниже
    SELECT value
    FROM sys.configurations
    WHERE name = 'backup compression default') AS BIT), 0)
DECLARE cur CURSOR FAST_FORWARD READ_ONLY LOCAL FOR
    SELECT d.name
    FROM sys.databases d
    WHERE d.[state] = 0
        AND d.name NOT IN ('tempdb') -- базы для которых не надо делать бекапов
OPEN cur
FETCH NEXT FROM cur INTO @db
WHILE @@FETCH_STATUS = 0 BEGIN
    IF DB_ID(@db) IS NULL BEGIN
        INSERT INTO dbo.BackupError (db, msg) VALUES (@db, 'db is missing')
    END
    ELSE IF DATABASEPROPERTYEX(@db, 'Status') != 'ONLINE' BEGIN
        INSERT INTO dbo.BackupError (db, msg) VALUES (@db, 'db state != ONLINE')
    END
    ELSE BEGIN
        BEGIN TRY
            SET @name = @path + '\T' + CONVERT(CHAR(8), GETDATE(), 112) + '_' + @db + '.bak'
            SET @sql = '
                BACKUP DATABASE ' + QUOTENAME(@db) + '
                TO DISK = ''' + @name + ''' WITH NOFORMAT, INIT' + 
                CASE WHEN @can_compress = 1 THEN ', COMPRESSION' ELSE '' END
            --PRINT @sql
            EXEC sys.sp_executesql @sql
        END TRY
        BEGIN CATCH
            INSERT INTO dbo.BackupError (db, msg) VALUES (@db, ERROR_MESSAGE())
        END CATCH
    END
    FETCH NEXT FROM cur INTO @db
END
CLOSE cur
DEALLOCATE cur


--Отправка сообщения на почту при возникновении ошибок 
IF EXISTS(SELECT 1 FROM dbo.BackupError) BEGIN
    DECLARE @report NVARCHAR(MAX)
    SET @report =
        '<table border="1"><tr><th>database</th><th>date</th><th>message</th></tr>' +
        CAST(( 
            SELECT td = db, '', td = dt, '', td = msg
            FROM dbo.BackupError
            FOR XML PATH('tr'), TYPE
        ) AS NVARCHAR(MAX)) +
        '</table>'
    EXEC msdb.dbo.sp_send_dbmail
        @recipients = 'kb2_mvv@student.ztu.edu.ua',
        @subject = 'Проблемы с бэкапом!',
        @body = @report,
        @body_format = 'HTML'
END

--Мониторинг последних бэкапов
SELECT
      database_name
    , backup_size_mb = backup_size / 1048576.0
    , compressed_backup_size_mb = compressed_backup_size / 1048576.0
    , compress_ratio_percent = 100 - compressed_backup_size * 100. / backup_size
FROM (
   SELECT
          database_name
        , backup_size
        , compressed_backup_size = NULLIF(compressed_backup_size, backup_size)
        , RowNumber = ROW_NUMBER() OVER (PARTITION BY database_name ORDER BY backup_finish_date DESC)
    FROM msdb.dbo.backupset
    WHERE [type] = 'D'
) t
WHERE t.RowNumber = 1

--Мониторинг баз для которых создавались бэкапы
SELECT
	d.name
    , rec_model = d.recovery_model_desc
    , f.full_time
    , f.full_last_date
    , f.full_size
    , f.log_time
    , f.log_last_date
    , f.log_size
FROM sys.databases d
LEFT JOIN (
    SELECT
	    database_name
	  , full_time = MAX(CASE WHEN [type] = 'D' THEN CONVERT(CHAR(10), backup_finish_date - backup_start_date, 108) END)
	  , full_last_date = MAX(CASE WHEN [type] = 'D' THEN backup_finish_date END)
	  , full_size = MAX(CASE WHEN [type] = 'D' THEN backup_size END)
	  , log_time = MAX(CASE WHEN [type] = 'L' THEN CONVERT(CHAR(10), backup_finish_date - backup_start_date, 108) END)
	  , log_last_date = MAX(CASE WHEN [type] = 'L' THEN backup_finish_date END)
	  , log_size = MAX(CASE WHEN [type] = 'L' THEN backup_size END)
    FROM (
	  SELECT
		  s.database_name
		, s.[type]
		, s.backup_start_date
		, s.backup_finish_date
		, backup_size =
				CASE WHEN s.backup_size = s.compressed_backup_size
						THEN s.backup_size
						ELSE s.compressed_backup_size
				END / 1048576.0
		, RowNum = ROW_NUMBER() OVER (PARTITION BY s.database_name, s.[type] ORDER BY s.backup_finish_date DESC)
	  FROM msdb.dbo.backupset s
	  WHERE s.[type] IN ('D', 'L')
    ) f
    WHERE f.RowNum = 1
    GROUP BY f.database_name
) f ON f.database_name = d.name

--Получение о заполненности файлу данных и лога для БД
IF OBJECT_ID('tempdb.dbo.#space') IS NOT NULL
    DROP TABLE #space
CREATE TABLE #space (
    database_id INT PRIMARY KEY,
    data_used_size DECIMAL(18,6),
    log_used_size DECIMAL(18,6)
)
DECLARE @SQL NVARCHAR(MAX)
SELECT @SQL = STUFF((
    SELECT '
    USE [' + d.name + ']
    INSERT INTO #space (database_id, data_used_size, log_used_size)
    SELECT
	    DB_ID()
	  , SUM(CASE WHEN [type] = 0 THEN space_used END)
	  , SUM(CASE WHEN [type] = 1 THEN space_used END)
    FROM (
	  SELECT s.[type], space_used = SUM(FILEPROPERTY(s.name, ''SpaceUsed'') * 8. / 1024)
	  FROM sys.database_files s
	  GROUP BY s.[type]
    ) t;'
    FROM sys.databases d
    WHERE d.[state] = 0
    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '')
EXEC sys.sp_executesql @SQL
SELECT 
	database_name = DB_NAME(t.database_id)
    , t.data_size
    , s.data_used_size
    , t.log_size
    , s.log_used_size
    , t.total_size
FROM (
    SELECT
	    database_id
	  , log_size = SUM(CASE WHEN [type] = 1 THEN size END) * 8. / 1024
	  , data_size = SUM(CASE WHEN [type] = 0 THEN size END) * 8. / 1024
	  , total_size = SUM(size) * 8. / 1024
    FROM sys.master_files
    GROUP BY database_id
) t
LEFT JOIN #space s ON t.database_id = s.database_id