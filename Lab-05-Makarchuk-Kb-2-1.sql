--�������� �������������� �����
CREATE SYMMETRIC KEY s_key1
WITH ALGORITHM = aes_128
ENCRYPTION BY PASSWORD = '1111'

--�������� ����� ������� 
select *
into Patient_copy1
from dbo.Patient_copy
where 1<>1;
select * from Patient_copy1

--�������� �����
open symmetric key s_key1 decryption by
password = '1111'


--���� ��������
INSERT INTO Patient_copy1 
 Values
 ('�����','2001-06-24','��������� 1',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255), 'ĳ�����2')), 1 , 1),
 ('�����','2000-09-28','�������� 22',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'ĳ�����2')), 2, 2),
 ('�������','1999-08-12','���������� 49',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'ĳ�����3')), 3, 3),
 ('���������','1980-02-14','������������� 17',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'ĳ�����4')), 4, 4),
 ('����','2002-01-03','����������� 8',EncryptByKey(Key_GUID('s_key1'), convert(nvarchar(255),'ĳ�����1')), 5, 5)
 
select * from Patient_copy1

--���������� 
select convert(nvarchar(255), DecryptByKey(Diagnosos))
from Patient_copy1

-- �������� ������������� �����
create asymmetric key as_key1
with algorithm  = rsa_2048
encryption by password = '1111'

--�������� ��� �����
select *
into Patient_copy2
from dbo.Patient_copy
where 1 <> 1;
select * from Patient_copy2

--���� ��������
INSERT INTO Patient_copy2
 Values
 ('�����','2001-06-24','��������� 1',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255), 'ĳ�����2')), 1 , 1),
 ('�����','2000-09-28','�������� 22',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'ĳ�����2')), 2, 2),
 ('�������','1999-08-12','���������� 49',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'ĳ�����3')), 3, 3),
 ('���������','1980-02-14','������������� 17',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'ĳ�����4')), 4, 4),
 ('����','2002-01-03','����������� 8',EncryptByAsymKey(AsymKey_ID('as_key1'), convert(nvarchar(255),'ĳ�����1')), 5, 5)
 
select * from Patient_copy2

--����������
SELECT Convert(nvarchar(50), DecryptByAsymKey(AsymKey_ID('as_key1'), Diagnosos, N'1111'))
FROM Patient_copy2

--�������� �������� �����
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'pass';
--�������� ��������� ����� �����
backup master key to file = 'D:\����\������������� ��\MasterKey.bak'
encryption by password = '1111'

--�������� ����������� 
use master
 CREATE CERTIFICATE TDECertificate WITH SUBJECT ='TDE Certificate for DBClients'
 select * from sys.certificates where name='TDECertificate'


 --�������� ��������� ����� �����������
 BACKUP CERTIFICATE TDECertificate
 TO FILE = 'D:\����\������������� ��\TDECertificate'
 WITH PRIVATE KEY
 (
	 FILE = 'D:\����\������������� ��\PrivateKeyFile',
	 ENCRYPTION BY PASSWORD = '1111'
 );
-- �������� ����� ����������
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_128
ENCRYPTION BY SERVER CERTIFICATE TDECertificate;
--��������� ���������� ��� ����
ALTER DATABASE kb22_6_hospital
SET ENCRYPTION ON;
SELECT DB_NAME(database_id), * FROM sys.dm_database_encryption_keys


--�������� �������������� ������� ��� �������
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