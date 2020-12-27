--������� 1
--�������� ���� ������
create database test_var3

--�������� ������
create table assignment(
	id_assignment int identity(1,1) primary key,
	date_of_give date,
	labor_intensity int, 
	planned_end_date date,
	real_end_date date
);

create table employee(
	id_employee int identity(1,1) primary key,
	full_name nvarchar(80),
	post nvarchar(40),
	table_num int not null,
	id_assignment int,
	foreign key (id_assignment) references assignment(id_assignment)
);

create table work(
	id_work int identity(1,1) primary key, 
	[name] nvarchar(50),
	�ipher nvarchar(20),
	end_date date,
	labor_intensity int,
	id_assignment int,
	foreign key (id_assignment) references assignment(id_assignment)
);

--��������� ������ �������
insert into assignment(date_of_give,labor_intensity, planned_end_date, real_end_date)
values
('2019-12-07', 4, '2019-12-17', '2019-12-10'),
('2020-06-01', 9, '2020-07-24', '2020-07-07')

insert into work(name, �ipher, end_date, labor_intensity, id_assignment)
values
('������ ���������', 12, '2020-10-14', 4, 2),
('���������� �����', 126, '2019-12-24', 9, 1)

insert into employee(full_name, post, table_num, id_assignment)
values
('�������� �����', '�������', 165, 2),
('������� �������', '��������� ������', 4, 1)

--����� ������ ���� �������� � ������
SELECT * FROM assignment
SELECT * FROM work
SELECT * FROM employee


--������� 2
--����������� ��������� � ������������ ��������
create clustered index clus_idx
on dbo.assignment(id_assignment);

create nonclustered index nonclus_idx
on dbo.work(labor_intensity);


--������� 3
--����� ������ �������� �� ������
select OBJECT_NAME(object_id) as table_name,
name as index_name, type, type_desc
from sys.indexes
where OBJECT_ID = OBJECT_ID(N'assignment')

select OBJECT_NAME(object_id) as table_name,
name as index_name, type, type_desc
from sys.indexes
where OBJECT_ID = OBJECT_ID(N'work')


--������� 5
--�������� 3-�� �������������
create login [admin] with password = 'admin'
create user [admin] for login [admin]
grant select, insert on assignment to [admin]

create login manager with password = 'qwerty123'
create user manager for login manager
grant insert, delete on work to manager

create login [user] with password = '1111'
create user [user] for login [user]
grant select on employee to [user]

--������� 6 
--���������� ����������� ����������
use [master]
go
create master key encryption BY PASSWORD = 'qwerty'
create certificate TDE_Cert 
WITH SUBJECT = 'TDE certificate for test_var3'
go
use test_var3
go
create database encryption key
with algorithm = aes_128 
encryption by server certificate TDE_Cert
go
alter database test_var3
set encryption on
go


--������� 7
--�������� ����������������� �������������� ��
backup database test_var3
to disk = 'D:\����\������������� ��\test_var3_backup.bak'
with noformat
go
backup database test_var3
to disk = 'D:\����\������������� ��\test_var3_backup.bak'
with noformat, description = 'test_var3 Database Full Backup',
stats = 10, differential, noinit, retaindays = 7, skip, rewind

backup log test_var3
to disk = 'D:\����\������������� ��\test_var3_log.trn'


--������� 8
--�������������� �� �� �����
restore database test_var3
from disk = 'D:\����\������������� ��\test_var3_backup.bak'