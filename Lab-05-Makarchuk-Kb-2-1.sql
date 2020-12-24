--Создание семетрического ключа
CREATE SYMMETRIC KEY s_key1
WITH ALGORITHM = aes_128
ENCRYPTION BY PASSWORD = '1111'

--Создание копии таблицы 
select *
into Patient_copy1
from dbo.Patient_copy
where 1<>1;
select * from Patient_copy1

--Открытие ключа
open symmetric key s_key1 decryption by
password = '1111'


--Шифр Диагноза
INSERT INTO Patient_copy1 
 Values
 ('Андрій','2001-06-24','Шелушкова 1',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255), 'Діагноз2')), 1 , 1),
 ('Єфрем','2000-09-28','Перемоги 22',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'Діагноз2')), 2, 2),
 ('Анатолій','1999-08-12','Центральна 49',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'Діагноз3')), 3, 3),
 ('Владислав','1980-02-14','Лятошинського 17',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'Діагноз4')), 4, 4),
 ('Олег','2002-01-03','Михайлівська 8',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'Діагноз1')), 5, 5)
 
select * from Patient_copy1

--Дешифровка 
select convert(nvarchar(255), DecryptByKey(Diagnosos))
from Patient_copy1

-- Создпние асиметричного ключа
create asymmetric key as_key1
with algorithm  = rsa_2048
encryption by password = '1111'

--Создание доп копии
select *
into Patient_copy2
from dbo.Patient_copy
where 1 <> 1;
select * from Patient_copy2

--Шифр Диагноза
INSERT INTO Patient_copy2
 Values
 ('Андрій','2001-06-24','Шелушкова 1',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255), 'Діагноз2')), 1 , 1),
 ('Єфрем','2000-09-28','Перемоги 22',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'Діагноз2')), 2, 2),
 ('Анатолій','1999-08-12','Центральна 49',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'Діагноз3')), 3, 3),
 ('Владислав','1980-02-14','Лятошинського 17',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'Діагноз4')), 4, 4),
 ('Олег','2002-01-03','Михайлівська 8',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'Діагноз1')), 5, 5)
 
select * from Patient_copy2

--Дешифровка
SELECT Convert(nvarchar(50), DecryptByAsymKey(AsymKey_ID('as_key1'), Diagnosos, N'1111'))
FROM Patient_copy2

--Создание главного ключа
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'pass';
--Создание резервной копии ключа
backup master key to file = 'D:\Ждту\Адміністрування БД\MasterKey.bak'
encryption by password = '1111'

--Создание сертификата 
use master
 CREATE CERTIFICATE TDECertificate WITH SUBJECT ='TDE Certificate for DBClients'
 select * from sys.certificates where name='TDECertificate'


 --Создание резервной копии сертификата
 BACKUP CERTIFICATE TDECertificate
 TO FILE = 'D:\Ждту\Адміністрування БД\TDECertificate'
 WITH PRIVATE KEY
 (
	 FILE = 'D:\Ждту\Адміністрування БД\PrivateKeyFile',
	 ENCRYPTION BY PASSWORD = '1111'
 );
-- Создание ключа шифрования
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_128
ENCRYPTION BY SERVER CERTIFICATE TDECertificate;
--Включение шифрования для базы
ALTER DATABASE kb22_6_hospital
SET ENCRYPTION ON;
SELECT DB_NAME(database_id), * FROM sys.dm_database_encryption_keys


--Создание зашифрованного столбца для таблицы
GO  
CREATE CERTIFICATE Patient 
   WITH SUBJECT = 'Secret Diagnos';  
GO  

CREATE SYMMETRIC KEY SSN_Key1  
    WITH ALGORITHM = AES_128  
    ENCRYPTION BY CERTIFICATE Patient;  
GO  

ALTER TABLE dbo.Patient
    ADD EncryptedDiagnos varbinary(128);   
GO  

OPEN SYMMETRIC KEY SSN_Key1  
   DECRYPTION BY CERTIFICATE Patient;  
UPDATE dbo.Patient
SET EncryptedDiagnos = EncryptByKey(Key_GUID('SSN_Key1'), diagnosos);  
GO
select * from dbo.Patient



OPEN SYMMETRIC KEY SSN_Key1  
   DECRYPTION BY CERTIFICATE Patient;  
GO  

SELECT diagnosos, EncryptedDiagnos
    AS 'Encrypted Diagnos',  
    CONVERT(nvarchar, DecryptByKey(EncryptedDiagnos))   
    AS 'Decrypted Diagnos'  
    FROM Patient;  


	select * from Patient