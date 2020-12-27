--Задание 1
--Создание базы данных
create database test_var3

--Создание таблиц
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
	сipher nvarchar(20),
	end_date date,
	labor_intensity int,
	id_assignment int,
	foreign key (id_assignment) references assignment(id_assignment)
);

--Заполение таблиц данными
insert into assignment(date_of_give,labor_intensity, planned_end_date, real_end_date)
values
('2019-12-07', 4, '2019-12-17', '2019-12-10'),
('2020-06-01', 9, '2020-07-24', '2020-07-07')

insert into work(name, сipher, end_date, labor_intensity, id_assignment)
values
('Уборка територии', 12, '2020-10-14', 4, 2),
('Разработка плана', 126, '2019-12-24', 9, 1)

insert into employee(full_name, post, table_num, id_assignment)
values
('Владимир Мунин', 'Уборщик', 165, 2),
('Аркадий Спасибо', 'Начальник отдела', 4, 1)

--Вывод данных всех столбцов с таблиц
SELECT * FROM assignment
SELECT * FROM work
SELECT * FROM employee


--Задание 2
--Определение класреных и некластерных индексов
create clustered index clus_idx
on dbo.assignment(id_assignment);

create nonclustered index nonclus_idx
on dbo.work(labor_intensity);


--Задание 3
--Вывод списка индексов из таблиц
select OBJECT_NAME(object_id) as table_name,
name as index_name, type, type_desc
from sys.indexes
where OBJECT_ID = OBJECT_ID(N'assignment')

select OBJECT_NAME(object_id) as table_name,
name as index_name, type, type_desc
from sys.indexes
where OBJECT_ID = OBJECT_ID(N'work')


--Задание 5
--Создание 3-ех пользователей
create login [admin] with password = 'admin'
create user [admin] for login [admin]
grant select, insert on assignment to [admin]

create login manager with password = 'qwerty123'
create user manager for login manager
grant insert, delete on work to manager

create login [user] with password = '1111'
create user [user] for login [user]
grant select on employee to [user]

--Задание 6 
--Выполнение прозрачного шифрования
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


--Задание 7
--Создание дифференциального резервирования БД
backup database test_var3
to disk = 'D:\Ждту\Адміністрування БД\test_var3_backup.bak'
with noformat
go
backup database test_var3
to disk = 'D:\Ждту\Адміністрування БД\test_var3_backup.bak'
with noformat, description = 'test_var3 Database Full Backup',
stats = 10, differential, noinit, retaindays = 7, skip, rewind

backup log test_var3
to disk = 'D:\Ждту\Адміністрування БД\test_var3_log.trn'


--Задание 8
--Восстановление БД из копии
restore database test_var3
from disk = 'D:\Ждту\Адміністрування БД\test_var3_backup.bak'