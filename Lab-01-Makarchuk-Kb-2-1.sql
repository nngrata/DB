-- Первое задание
-- Имена сервера и экземпляра 
Select @@SERVERNAME as [Server\Instance]; 
-- версия SQL Server 
Select @@VERSION as SQLServerVersion; 
-- экземпляр SQL Server 
Select @@ServiceName AS ServiceInstance;
 -- Текущая БД (БД, в контексте которой выполняется запрос)
Select DB_NAME() AS CurrentDB_Name;
--Cтарт сервера, период в днях и секундах
SELECT  @@Servername AS ServerName ,
        create_date AS  ServerStarted ,
        DATEDIFF(s, create_date, GETDATE()) / 86400.0 AS DaysRunning ,
        DATEDIFF(s, create_date, GETDATE()) AS SecondsRunnig
FROM    sys.databases
WHERE   name = 'tempdb'; 
GO

--Второе задание
EXEC sp_helpdb; 
--OR 
EXEC sp_Databases; 
--OR 
SELECT  @@SERVERNAME AS Server ,
        name AS DBName ,
        recovery_model_Desc AS RecoveryModel ,
        Compatibility_level AS CompatiblityLevel ,
        create_date ,
        state_desc
FROM    sys.databases
ORDER BY Name; 
--OR 
SELECT  @@SERVERNAME AS Server ,
        d.name AS DBName ,
        create_date ,
        compatibility_level ,
        m.physical_name AS FileName
FROM    sys.databases d
        JOIN sys.master_files m ON d.database_id = m.database_id
WHERE   m.[type] = 0 -- data files only
ORDER BY d.name; 
GO

--Третье задание
USE kb22_6_hospital;
GO
SELECT  *
FROM    sys.objects
WHERE   type = 'U';
--Расположение всех файлов баз данных
EXEC sp_Helpfile; 
--OR 
SELECT  @@Servername AS Server ,
        DB_NAME() AS DB_Name ,
        File_id ,
        Type_desc ,
        Name ,
        LEFT(Physical_Name, 1) AS Drive ,
        Physical_Name ,
        RIGHT(physical_name, 3) AS Ext ,
        Size ,
        Growth
FROM    sys.database_files
ORDER BY File_id; 
GO
--Таблицы
EXEC sp_tables; -- Помните, что этот метод вернёт и таблицы, и представления 
--OR 
SELECT  @@Servername AS ServerName ,
        TABLE_CATALOG ,
        TABLE_SCHEMA ,
        TABLE_NAME
FROM     INFORMATION_SCHEMA.TABLES
WHERE   TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME ;
--OR
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        o.name AS 'TableName' ,
        o.[Type] ,
        o.create_date
FROM    sys.objects o
WHERE   o.Type = 'U' -- User table 
ORDER BY o.name;
--OR 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        t.Name AS TableName,
        t.[Type],
        t.create_date
FROM    sys.tables t
ORDER BY t.Name;
GO

--Четвертое задание
SELECT  'Select ''' + DB_NAME() + '.' + SCHEMA_NAME(SCHEMA_ID) + '.'
        + LEFT(o.name, 128) + ''' as DBName, count(*) as Count From ' + SCHEMA_NAME(SCHEMA_ID) + '.' + o.name
        + ';' AS ' Script generator to get counts for all tables'
FROM    sys.objects o
WHERE   o.[type] = 'U'
ORDER BY o.name;
--sp_msforechtable
CREATE TABLE #rowcount
    ( Tablename VARCHAR(128) ,
      Rowcnt INT ); 
EXEC sp_MSforeachtable 'insert into #rowcount select ''?'', count(*) from ?' 
SELECT  *
FROM    #rowcount
ORDER BY Tablename ,
        Rowcnt; 
DROP TABLE #rowcount;

--Пятое задание
-- Самый быстрый путь получения количества записей
-- Hint: получайте из индекса, а не таблицы
SELECT  @@ServerName AS Server ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(p.object_id) AS SchemaName ,
        OBJECT_NAME(p.object_id) AS TableName ,
        i.Type_Desc ,
        i.Name AS IndexUsedForCounts ,
        SUM(p.Rows) AS Rows
FROM    sys.partitions p
        JOIN sys.indexes i ON i.object_id = p.object_id
                              AND i.index_id = p.index_id
WHERE   i.type_desc IN ( 'CLUSTERED', 'HEAP' )
                             -- This is key (1 index per table) 
        AND OBJECT_SCHEMA_NAME(p.object_id) <> 'sys'
GROUP BY p.object_id ,
        i.type_desc ,
        i.Name
ORDER BY SchemaName ,
        TableName; 
-- OR 
-- Похожий метод получения количества записей, но с использованием DMV dm_db_partition_stats 
SELECT  @@ServerName AS ServerName ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(ddps.object_id) AS SchemaName ,
        OBJECT_NAME(ddps.object_id) AS TableName ,
        i.Type_Desc ,
        i.Name AS IndexUsedForCounts ,
        SUM(ddps.row_count) AS Rows
FROM    sys.dm_db_partition_stats ddps
        JOIN sys.indexes i ON i.object_id = ddps.object_id
                              AND i.index_id = ddps.index_id
WHERE   i.type_desc IN ( 'CLUSTERED', 'HEAP' )
                              -- This is key (1 index per table) 
        AND OBJECT_SCHEMA_NAME(ddps.object_id) <> 'sys'
GROUP BY ddps.object_id ,
        i.type_desc ,
        i.Name
ORDER BY SchemaName ,
        TableName;
GO
--Работа с кучами
-- Кучи (метод 1)
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        t.Name AS HeapTable ,
        t.Create_Date
FROM    sys.tables t
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
                                    AND i.type_desc = 'HEAP'
ORDER BY t.Name 
--OR 
-- Кучи (Метод 2) 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        t.Name AS HeapTable ,
        t.Create_Date
FROM    sys.tables t
WHERE    OBJECTPROPERTY(OBJECT_ID, 'TableHasClustIndex') = 0
ORDER BY t.Name; 
--OR 
-- Кучи (Метод 3) + количество записей
SELECT  @@ServerName AS Server ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(ddps.object_id) AS SchemaName ,
        OBJECT_NAME(ddps.object_id) AS TableName ,
        i.Type_Desc ,
        SUM(ddps.row_count) AS Rows
FROM    sys.dm_db_partition_stats AS ddps
        JOIN sys.indexes i ON i.object_id = ddps.object_id
                              AND i.index_id = ddps.index_id
WHERE   i.type_desc = 'HEAP'
        AND OBJECT_SCHEMA_NAME(ddps.object_id) <> 'sys'
GROUP BY ddps.object_id ,
        i.type_desc
ORDER BY TableName;

--Шестое задание
-- Чтение/запись таблицы
-- Кучи не рассматриваются, у них нет индексов
-- Только те таблицы, к которым обращались после запуска SQL Server
SELECT  @@ServerName AS ServerName ,
        DB_NAME() AS DBName ,
        OBJECT_NAME(ddius.object_id) AS TableName ,
        SUM(ddius.user_seeks + ddius.user_scans + ddius.user_lookups)
                                                               AS  Reads ,
        SUM(ddius.user_updates) AS Writes ,
        SUM(ddius.user_seeks + ddius.user_scans + ddius.user_lookups
            + ddius.user_updates) AS [Reads&Writes] ,
        ( SELECT    DATEDIFF(s, create_date, GETDATE()) / 86400.0
          FROM      master.sys.databases
          WHERE     name = 'tempdb'
        ) AS SampleDays ,
        ( SELECT    DATEDIFF(s, create_date, GETDATE()) AS SecoundsRunnig
          FROM      master.sys.databases
          WHERE     name = 'tempdb'
        ) AS SampleSeconds
FROM    sys.dm_db_index_usage_stats ddius
        INNER JOIN sys.indexes i ON ddius.object_id = i.object_id
                                     AND i.index_id = ddius.index_id
WHERE    OBJECTPROPERTY(ddius.object_id, 'IsUserTable') = 1
        AND ddius.database_id = DB_ID()
GROUP BY OBJECT_NAME(ddius.object_id)
ORDER BY [Reads&Writes] DESC;
GO
-- Операции чтения и записи
-- Кучи пропущены, у них нет индексов
-- Только таблицы, использовавшиеся после перезапуска SQL Server
-- В запросе используется курсор для получения информации во всех БД
-- Единый отчёт, хранится в tempdb
DECLARE DBNameCursor CURSOR
FOR
    SELECT  Name
    FROM    sys.databases
    WHERE    Name NOT IN ( 'master', 'model', 'msdb', 'tempdb',
                            'distribution' )
    ORDER BY Name; 
DECLARE @DBName NVARCHAR(128) 
DECLARE @cmd VARCHAR(4000) 
IF OBJECT_ID(N'tempdb..TempResults') IS NOT NULL
    BEGIN 
        DROP TABLE tempdb..TempResults 
    END 
CREATE TABLE tempdb..TempResults
    (
      ServerName NVARCHAR(128) ,
      DBName NVARCHAR(128) ,
      TableName NVARCHAR(128) ,
      Reads INT ,
      Writes INT ,
      ReadsWrites INT ,
      SampleDays DECIMAL(18, 8) ,
      SampleSeconds INT
    ) 
OPEN DBNameCursor 
FETCH NEXT FROM DBNameCursor INTO @DBName 
WHILE @@fetch_status = 0
    BEGIN 
---------------------------------------------------- 
-- Print @DBName 
        SELECT   @cmd = 'Use ' + @DBName + '; ' 
        SELECT   @cmd = @cmd + ' Insert Into tempdb..TempResults 
SELECT @@ServerName AS ServerName, 
DB_NAME() AS DBName, 
object_name(ddius.object_id) AS TableName , 
SUM(ddius.user_seeks 
+ ddius.user_scans 
+ ddius.user_lookups) AS Reads, 
SUM(ddius.user_updates) as Writes, 
SUM(ddius.user_seeks 
+ ddius.user_scans 
+ ddius.user_lookups 
+ ddius.user_updates) as ReadsWrites, 
(SELECT datediff(s,create_date, GETDATE()) / 86400.0 
FROM sys.databases WHERE name = ''tempdb'') AS SampleDays, 
(SELECT datediff(s,create_date, GETDATE()) 
FROM sys.databases WHERE name = ''tempdb'') as SampleSeconds 
FROM sys.dm_db_index_usage_stats ddius 
INNER JOIN sys.indexes i
ON ddius.object_id = i.object_id 
AND i.index_id = ddius.index_id 
WHERE objectproperty(ddius.object_id,''IsUserTable'') = 1 --True 
AND ddius.database_id = db_id() 
GROUP BY object_name(ddius.object_id) 
ORDER BY ReadsWrites DESC;' 
--PRINT @cmd 
        EXECUTE (@cmd) 
----------------------------------------------------- 
        FETCH NEXT FROM DBNameCursor INTO @DBName 
    END 
CLOSE DBNameCursor 
DEALLOCATE DBNameCursor 
SELECT  *
FROM    tempdb..TempResults
ORDER BY DBName ,
        TableName; 
--DROP TABLE tempdb..TempResults;

--Представление
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        o.name AS ViewName ,
        o.[Type] ,
        o.create_date
FROM    sys.objects o
WHERE   o.[Type] = 'V' -- View 
ORDER BY o.NAME  
--OR 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        Name AS ViewName ,
        create_date
FROM    sys.Views
ORDER BY Name 
--OR
SELECT  @@Servername AS ServerName ,
        TABLE_CATALOG ,
        TABLE_SCHEMA ,
        TABLE_NAME ,
        TABLE_TYPE
FROM     INFORMATION_SCHEMA.TABLES
WHERE   TABLE_TYPE = 'VIEW'
ORDER BY TABLE_NAME 
--OR 
-- CREATE VIEW Code 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        o.name AS 'ViewName' ,
        o.Type ,
        o.create_date ,
        sm.[DEFINITION] AS 'View script'
FROM    sys.objects o
        INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
WHERE   o.Type = 'V' -- View 
ORDER BY o.NAME;
GO

--Процедуры
-- Хранимые процедуры 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        o.name AS StoredProcedureName ,
        o.[Type] ,
        o.create_date
FROM    sys.objects o
WHERE   o.[Type] = 'P' -- Stored Procedures 
ORDER BY o.name
--OR 
-- Дополнительная информация о ХП 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        o.name AS 'ViewName' ,
        o.[type] ,
        o.Create_date ,
        sm.[definition] AS 'Stored Procedure script'
FROM    sys.objects o
        INNER JOIN sys.sql_modules sm ON o.object_id = sm.object_id
WHERE   o.[type] = 'P' -- Stored Procedures 
        -- AND sm.[definition] LIKE '%insert%'
        -- AND sm.[definition] LIKE '%update%'
        -- AND sm.[definition] LIKE '%delete%'
        -- AND sm.[definition] LIKE '%tablename%'
ORDER BY o.name;
GO

--Функции
-- Функции
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        o.name AS 'Functions' ,
        o.[Type] ,
        o.create_date
FROM    sys.objects o
WHERE   o.Type = 'FN' -- Function 
ORDER BY o.NAME;
--OR 
-- Дополнительная информация о функциях
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        o.name AS 'FunctionName' ,
        o.[type] ,
        o.create_date ,
        sm.[DEFINITION] AS 'Function script'
FROM    sys.objects o
        INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
WHERE   o.[Type] = 'FN' -- Function 
ORDER BY o.NAME;
GO
-- Триггеры
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        parent.name AS TableName ,
        o.name AS TriggerName ,
        o.[Type] ,
        o.create_date
FROM    sys.objects o
        INNER JOIN sys.objects parent ON o.parent_object_id = parent.object_id
WHERE   o.Type = 'TR' -- Triggers 
ORDER BY parent.name ,
        o.NAME 
--OR 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        Parent_id ,
        name AS TriggerName ,
        create_date
FROM    sys.triggers
WHERE   parent_class = 1
ORDER BY name;
--OR 
-- Дополнительная информация о триггерах
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        OBJECT_NAME(Parent_object_id) AS TableName ,
        o.name AS 'TriggerName' ,
        o.Type ,
        o.create_date ,
        sm.[DEFINITION] AS 'Trigger script'
FROM    sys.objects o
        INNER JOIN sys.sql_modules sm ON o.object_id = sm.OBJECT_ID
WHERE   o.Type = 'TR' -- Triggers 
ORDER BY o.NAME;
GO
-- Check Constraints 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        parent.name AS 'TableName' ,
        o.name AS 'Constraints' ,
        o.[Type] ,
        o.create_date
FROM    sys.objects o
        INNER JOIN sys.objects parent
               ON o.parent_object_id = parent.object_id
WHERE   o.Type = 'C' -- Check Constraints 
ORDER BY parent.name ,
        o.name 
--OR 
--CHECK constriant definitions
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(parent_object_id) AS SchemaName ,
        OBJECT_NAME(parent_object_id) AS TableName ,
        parent_column_id AS  Column_NBR ,
        Name AS  CheckConstraintName ,
        type ,
        type_desc ,
        create_date ,
        OBJECT_DEFINITION(object_id) AS CheckConstraintDefinition
FROM    sys.Check_constraints
ORDER BY TableName ,
        SchemaName ,
        Column_NBR 
GO

--Седьмое задание
SELECT  @@Servername AS Server ,
        DB_NAME() AS DBName ,
        isc.Table_Name AS TableName ,
        isc.Table_Schema AS SchemaName ,
        Ordinal_Position AS  Ord ,
        Column_Name ,
        Data_Type ,
        Numeric_Precision AS  Prec ,
        Numeric_Scale AS  Scale ,
        Character_Maximum_Length AS LEN , -- -1 means MAX like Varchar(MAX) 
        Is_Nullable ,
        Column_Default ,
        Table_Type
FROM     INFORMATION_SCHEMA.COLUMNS isc
        INNER JOIN  information_schema.tables ist
              ON isc.table_name = ist.table_name 
--      WHERE Table_Type = 'BASE TABLE' -- 'Base Table' or 'View' 
ORDER BY DBName ,
        TableName ,
        SchemaName ,
        Ordinal_position;  
-- Имена столбцов и количество повторов
-- Используется для поиска одноимённых столбцов с разными типами данных/длиной
SELECT  @@Servername AS Server ,
        DB_NAME() AS DBName ,
        Column_Name ,
        Data_Type ,
        Numeric_Precision AS  Prec ,
        Numeric_Scale AS  Scale ,
        Character_Maximum_Length ,
        COUNT(*) AS Count
FROM     information_schema.columns isc
        INNER JOIN  information_schema.tables ist
               ON isc.table_name = ist.table_name
WHERE   Table_type = 'BASE TABLE'
GROUP BY Column_Name ,
        Data_Type ,
        Numeric_Precision ,
        Numeric_Scale ,
        Character_Maximum_Length; 
-- Информация по используемым типам данных
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        Data_Type ,
        Numeric_Precision AS  Prec ,
        Numeric_Scale AS  Scale ,
        Character_Maximum_Length AS [Length] ,
        COUNT(*) AS COUNT
FROM     information_schema.columns isc
        INNER JOIN  information_schema.tables ist
               ON isc.table_name = ist.table_name
WHERE   Table_type = 'BASE TABLE'
GROUP BY Data_Type ,
        Numeric_Precision ,
        Numeric_Scale ,
        Character_Maximum_Length
ORDER BY Data_Type ,
        Numeric_Precision ,
        Numeric_Scale ,
        Character_Maximum_Length  
-- Large object data types or Binary Large Objects(BLOBs) 
-- Помните, что индексы по этим таблицам не могут быть перестроены в режиме "online"
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        isc.Table_Name ,
        Ordinal_Position AS  Ord ,
        Column_Name ,
        Data_Type AS  BLOB_Data_Type ,
        Numeric_Precision AS  Prec ,
        Numeric_Scale AS  Scale ,
        Character_Maximum_Length AS [Length]
FROM     information_schema.columns isc
        INNER JOIN  information_schema.tables ist
               ON isc.table_name = ist.table_name
WHERE   Table_type = 'BASE TABLE'
        AND ( Data_Type IN ( 'text', 'ntext', 'image', 'XML' )
              OR ( Data_Type IN ( 'varchar', 'nvarchar', 'varbinary' )
                   AND Character_Maximum_Length = -1
                 )
            ) -- varchar(max), nvarchar(max), varbinary(max) 
ORDER BY isc.Table_Name ,
        Ordinal_position;

--Восьмое задание
-- Table Defaults 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        parent.name AS TableName ,
        o.name AS Defaults ,
        o.[Type] ,
        o.Create_date
FROM    sys.objects o
        INNER JOIN sys.objects parent
               ON o.parent_object_id = parent.object_id
WHERE   o.[Type] = 'D' -- Defaults 
ORDER BY parent.name ,
        o.NAME
--OR 
-- Column Defaults 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        OBJECT_SCHEMA_NAME(parent_object_id) AS SchemaName ,
        OBJECT_NAME(parent_object_id) AS TableName ,
        parent_column_id AS  Column_NBR ,
        Name AS DefaultName ,
        [type] ,
        type_desc ,
        create_date ,
        OBJECT_DEFINITION(object_id) AS Defaults
FROM    sys.default_constraints
ORDER BY TableName ,
        Column_NBR 
--OR 
-- Column Defaults 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        OBJECT_SCHEMA_NAME(t.object_id) AS SchemaName ,
        t.Name AS TableName ,
        c.Column_ID AS Ord ,
        c.Name AS Column_Name ,
        OBJECT_NAME(default_object_id) AS DefaultName ,
        OBJECT_DEFINITION(default_object_id) AS Defaults
FROM    sys.Tables t
        INNER JOIN sys.columns c ON t.object_id = c.object_id
WHERE    default_object_id <> 0
ORDER BY TableName ,
        SchemaName ,
        c.Column_ID 
GO

--Девятое задание
-- Вычисляемые столбцы
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(object_id) AS SchemaName ,
        OBJECT_NAME(object_id) AS Tablename ,
        Column_id ,
        Name AS  Computed_Column ,
        [Definition] ,
        is_persisted
FROM    sys.computed_columns
ORDER BY SchemaName ,
        Tablename ,
        [Definition]; 
--Or 
-- Computed Columns 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(t.object_id) AS SchemaName,
        t.Name AS TableName ,
        c.Column_ID AS Ord ,
        c.Name AS Computed_Column
FROM    sys.Tables t
        INNER JOIN sys.Columns c ON t.object_id = c.object_id
WHERE   is_computed = 1
ORDER BY t.Name ,
        SchemaName ,
        c.Column_ID 
GO

--Десятое задание
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DBName ,
        OBJECT_SCHEMA_NAME(object_id) AS SchemaName ,
        OBJECT_NAME(object_id) AS TableName ,
        Column_id ,
        Name AS  IdentityColumn ,
        Seed_Value ,
        Last_Value
FROM    sys.identity_columns
ORDER BY SchemaName ,
        TableName ,
        Column_id; 
GO

--Одинадцатое задание
--Ключи
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        o.Name AS TableName ,
        i.Name AS IndexName
FROM    sys.objects o
        INNER JOIN sys.indexes i ON o.object_id = i.object_id
WHERE   o.Type = 'U' -- User table 
        AND LEFT(i.Name, 1) <> '_' -- Remove hypothetical indexes 
ORDER BY o.NAME ,
        i.name; 
GO

-- Отсутствующие индексы из DMV
SELECT  @@ServerName AS ServerName ,
        DB_NAME() AS DBName ,
        t.name AS 'Affected_table' ,
        ( LEN(ISNULL(ddmid.equality_columns, N'')
              + CASE WHEN ddmid.equality_columns IS NOT NULL
                          AND ddmid.inequality_columns IS NOT NULL THEN ','
                     ELSE ''
                END) - LEN(REPLACE(ISNULL(ddmid.equality_columns, N'')
                                   + CASE WHEN ddmid.equality_columns
                                                             IS NOT NULL
                                               AND ddmid.inequality_columns
                                                             IS NOT NULL
                                          THEN ','
                                          ELSE ''
                                     END, ',', '')) ) + 1 AS K ,
        COALESCE(ddmid.equality_columns, '')
        + CASE WHEN ddmid.equality_columns IS NOT NULL
                    AND ddmid.inequality_columns IS NOT NULL THEN ','
               ELSE ''
          END + COALESCE(ddmid.inequality_columns, '') AS Keys ,
        COALESCE(ddmid.included_columns, '') AS [include] ,
        'Create NonClustered Index IX_' + t.name + '_missing_'
        + CAST(ddmid.index_handle AS VARCHAR(20)) 
        + ' On ' + ddmid.[statement] COLLATE database_default
        + ' (' + ISNULL(ddmid.equality_columns, '')
        + CASE WHEN ddmid.equality_columns IS NOT NULL
                    AND ddmid.inequality_columns IS NOT NULL THEN ','
               ELSE ''
          END + ISNULL(ddmid.inequality_columns, '') + ')'
        + ISNULL(' Include (' + ddmid.included_columns + ');', ';')
                                                  AS sql_statement ,
        ddmigs.user_seeks ,
        ddmigs.user_scans ,
        CAST(( ddmigs.user_seeks + ddmigs.user_scans )
        * ddmigs.avg_user_impact AS BIGINT) AS 'est_impact' ,
        avg_user_impact ,
        ddmigs.last_user_seek ,
        ( SELECT    DATEDIFF(Second, create_date, GETDATE()) Seconds
          FROM      sys.databases
          WHERE     name = 'tempdb'
        ) SecondsUptime 
FROM    sys.dm_db_missing_index_groups ddmig
        INNER JOIN sys.dm_db_missing_index_group_stats ddmigs
               ON ddmigs.group_handle = ddmig.index_group_handle
        INNER JOIN sys.dm_db_missing_index_details ddmid
               ON ddmig.index_handle = ddmid.index_handle
        INNER JOIN sys.tables t ON ddmid.OBJECT_ID = t.OBJECT_ID
WHERE   ddmid.database_id = DB_ID()
ORDER BY est_impact DESC;
GO

--Двенадцатое задание
-- Foreign Keys 
SELECT  @@Servername AS ServerName ,
        DB_NAME() AS DB_Name ,
        parent.name AS 'TableName' ,
        o.name AS 'ForeignKey' ,
        o.[Type] ,
        o.Create_date
FROM    sys.objects o
        INNER JOIN sys.objects parent ON o.parent_object_id = parent.object_id
WHERE   o.[Type] = 'F' -- Foreign Keys 
ORDER BY parent.name ,
        o.name 
--OR 
SELECT  f.name AS ForeignKey ,
        SCHEMA_NAME(f.SCHEMA_ID) AS SchemaName ,
        OBJECT_NAME(f.parent_object_id) AS TableName ,
        COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ColumnName ,
        SCHEMA_NAME(o.SCHEMA_ID) ReferenceSchemaName ,
        OBJECT_NAME(f.referenced_object_id) AS ReferenceTableName ,
        COL_NAME(fc.referenced_object_id, fc.referenced_column_id)
                                              AS ReferenceColumnName
FROM    sys.foreign_keys AS f
        INNER JOIN sys.foreign_key_columns AS fc
               ON f.OBJECT_ID = fc.constraint_object_id
        INNER JOIN sys.objects AS o ON o.OBJECT_ID = fc.referenced_object_id
ORDER BY TableName ,
        ReferenceTableName;
GO
-- Foreign Keys missing indexes 
-- Помните, что этот скрипт работает только для создания индексов по одному столбцу
-- Внешние ключи, состоящие более чем из одного столбца, не отслеживаются
SELECT  DB_NAME() AS DBName ,
        rc.Constraint_Name AS FK_Constraint , 
-- rc.Constraint_Catalog AS FK_Database, 
-- rc.Constraint_Schema AS FKSch, 
        ccu.Table_Name AS FK_Table ,
        ccu.Column_Name AS FK_Column ,
        ccu2.Table_Name AS ParentTable ,
        ccu2.Column_Name AS ParentColumn ,
        I.Name AS IndexName ,
        CASE WHEN I.Name IS NULL
             THEN 'IF NOT EXISTS (SELECT * FROM sys.indexes
                                    WHERE object_id = OBJECT_ID(N'''
                  + RC.Constraint_Schema + '.' + ccu.Table_Name
                  + ''') AND name = N''IX_' + ccu.Table_Name + '_'
                  + ccu.Column_Name + ''') '
                  + 'CREATE NONCLUSTERED INDEX IX_' + ccu.Table_Name + '_'
                  + ccu.Column_Name + ' ON ' + rc.Constraint_Schema + '.'
                  + ccu.Table_Name + '( ' + ccu.Column_Name
                  + ' ASC ) WITH (PAD_INDEX = OFF, 
                                   STATISTICS_NORECOMPUTE = OFF,
                                   SORT_IN_TEMPDB = ON, IGNORE_DUP_KEY = OFF,
                                   DROP_EXISTING = OFF, ONLINE = ON);'
             ELSE ''
        END AS SQL
FROM     information_schema.referential_constraints RC
        JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE ccu
         ON rc.CONSTRAINT_NAME = ccu.CONSTRAINT_NAME
        JOIN INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE ccu2
         ON rc.UNIQUE_CONSTRAINT_NAME = ccu2.CONSTRAINT_NAME
        LEFT JOIN sys.columns c ON ccu.Column_Name = C.name
                                AND ccu.Table_Name = OBJECT_NAME(C.OBJECT_ID)
        LEFT JOIN sys.index_columns ic ON C.OBJECT_ID = IC.OBJECT_ID
                                          AND c.column_id = ic.column_id
                                          AND index_column_id  = 1
                                           -- index found has the foreign key
                                          --  as the first column 
        LEFT JOIN sys.indexes i ON IC.OBJECT_ID = i.OBJECT_ID
                                   AND ic.index_Id = i.index_Id
WHERE   I.name IS NULL
ORDER BY FK_table ,
        ParentTable ,
        ParentColumn; 
GO

--Тринадцатое задание
EXEC sp_msdependencies '?' -- Displays Help 
EXEC sp_msdependencies NULL    -- Все зависимости в БД
EXEC sp_msdependencies NULL, 3 -- Зависимости определённой таблицы
-- sp_MSdependencies — Только верхний уровень
-- Объекты, которые зависят от указанного объекта
EXEC sp_MSdependencies N'personal_card',null, 1053183

--Список зависимостей
CREATE TABLE #TempTable1
    (
      Type INT ,
      ObjName VARCHAR(256) ,
      Owner VARCHAR(25) ,
      Sequence INT
    ); 
INSERT  INTO #TempTable1
        EXEC sp_MSdependencies NULL 
SELECT  *
FROM     #TempTable1
WHERE   Type = 8 --Tables 
ORDER BY Sequence ,
        ObjName 
DROP TABLE #TempTable1;
--Запросы к системным представлениям
--Independent tables
SELECT  Name AS InDependentTables
FROM    sys.tables
WHERE   object_id NOT IN ( SELECT  referenced_object_id
                             FROM   sys.foreign_key_columns )
                                                -- Check for parents
        AND object_id NOT IN ( SELECT parent_object_id
                                 FROM   sys.foreign_key_columns )
                                               -- Check for Dependents
ORDER BY Name 
-- Tables with dependencies.
SELECT DISTINCT
        OBJECT_NAME(referenced_object_id) AS ParentTable ,
        OBJECT_NAME(parent_object_id) AS DependentTable ,
        OBJECT_NAME(constraint_object_id) AS ForeignKeyName
FROM    sys.foreign_key_columns
ORDER BY ParentTable ,
        DependentTable 
-- Top level of the pyramid tables. Tables with no parents.
SELECT DISTINCT
        OBJECT_NAME(referenced_object_id) AS TablesWithNoParent
FROM    sys.foreign_key_columns
WHERE    referenced_object_id NOT IN ( SELECT  parent_object_id
                                        FROM    sys.foreign_key_columns )
ORDER BY 1 
-- Bottom level of the pyramid tables. 
-- Tables with no dependents. (These are the leaves on a tree.)
SELECT DISTINCT
        OBJECT_NAME(parent_object_id) AS TablesWithNoDependents
FROM    sys.foreign_key_columns
WHERE   parent_object_id NOT IN ( SELECT  referenced_object_id
                                    FROM    sys.foreign_key_columns )
ORDER BY 1
-- Tables with both parents and dependents. 
-- Tables in the middle of the hierarchy
SELECT DISTINCT
        OBJECT_NAME(referenced_object_id) AS MiddleTables
FROM    sys.foreign_key_columns
WHERE    referenced_object_id IN ( SELECT  parent_object_id
                                    FROM    sys.foreign_key_columns )
        AND parent_object_id  NOT IN ( SELECT   referenced_object_id
                                        FROM    sys.foreign_key_columns )
ORDER BY 1;
-- in rare cases, you might find a self-referencing dependent table.
-- Recursive (self) referencing table dependencies. 
SELECT DISTINCT
        OBJECT_NAME(referenced_object_id) AS ParentTable ,
        OBJECT_NAME(parent_object_id) AS ChildTable ,
        OBJECT_NAME(constraint_object_id) AS ForeignKeyName
FROM    sys.foreign_key_columns
WHERE    referenced_object_id = parent_object_id
ORDER BY 1 ,
        2;
--Использование СТЕ
-- How to find the hierarchical dependencies
-- Solve recursive queries using Common Table Expressions (CTE)
WITH     TableHierarchy (  ParentTable, DependentTable, Level )
          AS (
-- Anchor member definition (First level group to start the process)
               SELECT DISTINCT
                        CAST(NULL AS  INT) AS ParentTable ,
                        e.referenced_object_id AS DependentTable ,
                        0 AS Level
               FROM     sys.foreign_key_columns AS e
               WHERE    e.referenced_object_id NOT IN (
                        SELECT  parent_object_id
                        FROM    sys.foreign_key_columns )
-- Add filter dependents of only one parent table
-- AND Object_Name(e.referenced_object_id) = 'User'
               UNION ALL
-- Recursive member definition (Find all the layers of dependents)
               SELECT --Distinct
                        e.referenced_object_id AS ParentTable ,
                        e.parent_object_id AS DependentTable ,
                        Level + 1
               FROM     sys.foreign_key_columns AS e
                        INNER JOIN TableHierarchy AS d
                               ON ( e.referenced_object_id ) = 
                                                      d.DependentTable
             )
    -- Statement that executes the CTE
SELECT DISTINCT
        OBJECT_NAME(ParentTable) AS ParentTable ,
        OBJECT_NAME(DependentTable) AS DependentTable ,
        Level
FROM     TableHierarchy
ORDER BY Level ,
        ParentTable ,
        DependentTable;
