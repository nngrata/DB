use kb22_6_hospital

--Backup
BACKUP DATABASE kb22_6_hospital
TO DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_Backup.bak' WITH INIT, NAME = 'hospital Full DB Backup',
DESCRIPTION = 'hospital Full Database Backup'

--Restore
RESTORE DATABASE kb22_6_hospital
FROM DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_Backup.bak'
WITH RECOVERY, REPLACE

--Backup Log
BACKUP LOG kb22_6_hospital
WITH TRUNCATE_ONLY

--Full backup with log
BACKUP DATABASE kb22_6_hospital
TO DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_Backup.bak' 
WITH INIT, NAME = 'hospital Full DB Backup',
DESCRIPTION = 'hospital Full Database Backup'
BACKUP LOG kb22_6_hospital
TO DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_TlogBkup.bak' 
WITH NOINIT, NAME = 'hospital Translog Backup',
DESCRIPTION = 'hospital Full Transactin Log Backup', NOFORMAT

--Backup last element of log
BACKUP LOG kb22_6_hospital
TO DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_TaillogBkup.bak' 
WITH NORECOVER

 --Restore DB files 
RESTORE DATABASE kb22_6_hospital
FROM DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_FullDbBkup.bak' 
WITH NORECOVERY

--Restore all logs with 'NORECOVERY'
RESTORE LOG kb22_6_hospital
FROM DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_TlogBkup.bak' 
WITH NORECOVERY

--Restore last elements of log with 'RECOVERY'
RESTORE LOG kb22_6_hospital
FROM DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_TaillogBkup.bak' 
WITH RECOVERY

--Backup differential copy
BACKUP DATABASE sport_clubs_CP
TO DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_DiffDbBkup.bak' 
WITH INIT, DIFFERENTIAL, NAME = 'kb22_6_hospital Diff Db backup',
DESCRIPTION = 'kb2_6_hospital Differential Database Backup'

--Restore differential copy

RESTORE DATABASE sport_clubs_CP
FROM DISK = 'D:\Ждту\Адміністрування БД\lab02\hospital_DiffDbBkup.bak' 
WITH NORECOVERY


--Пользователи
create login test_login with password = '1'
use kb22_6_hospital
create user test_login for login test_login

--роли БД
alter role db_backupoperator add member test_login
exec sp_helprolemember

--новая роль БД
create role test_role authorization db_ddladmin
alter role db_ddladmin add member test_login
alter role db_ddladmin drop member test_login

--разрешения для роли
grant select on visiting_accounting to test_role
deny insert on visiting_accounting to test_role
deny delete on visiting_accounting to test_role
grant update on visiting_accounting to test_role
--разрешения для пользователя
grant select to test_login
revoke insert to test_login
deny delete to test_login

--Серверные роли
USE [master]
GO
CREATE SERVER ROLE [BulkAdmin] AUTHORIZATION [sa]
GO
ALTER SERVER ROLE [BulkAdmin] ADD MEMBER [test_login]
GO
GRANT Administer Bulk Operations TO [SugonyakBulkAdmin]
GO

--Проверка прав доступа:
SELECT DB_NAME() AS 'Database', p.name, p.type_desc, p.is_fixed_role, dbp.state_desc,
dbp.permission_name, so.name, so.type_desc
FROM sys.database_permissions dbp
LEFT JOIN sys.objects so ON dbp.major_id = so.object_id
LEFT JOIN sys.database_principals p ON dbp.grantee_principal_id = p.principal_id
--WHERE p.name = 'ProdDataEntry'
ORDER BY so.name, dbp.permission_name;

--Проверка применения прав:
EXECUTE AS LOGIN = 'ISUGON';

REVERT;

--Просмотр ролей:
--Роли на сервере:
exec sp_helpsrvrolemember
--Роли и в БД
exec sp_helpsrvrolemember

--Создание пользователя
exec sp_addlogin @loginame = 'test2_login',  @passwd='2'

exec sp_adduser 'test2_login', 'test2_loginu'

grant select ON tarif to test2_loginu

--создание роли
exec sp_addrole df
grant create table to df
--Проверка
exec sp_helpuser

--СИСТЕМНІ ПРОЦЕДУРИ--

--новий логін
exec sp_addlogin @loginame = 'adminer', @passwd = '123', @defdb = 'kb22_6_hospital';
use kb22_6_hospital;
--новий користувач
exec sp_adduser @loginame = 'adminer', @name_in_db = 'administrator';
--нова роль БД
exec sp_addrole @rolename = 'adminer_role', @ownername = 'administrator';
exec sp_addrolemember @rolename = 'adminer_role', @membername = 'administrator';
--права у ролі
grant select, alter, insert, update, delete on visiting_accounting to administrator;

