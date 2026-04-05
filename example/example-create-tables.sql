-- Получаем список доступных таблиц 1С
select * from pg1c.metadata_tables();

-- Создаем таблицу
select pg1c.create_table('Справочник.Контрагенты');

-- Создаем таблицу с другими схемой и названием (public.Goods) в PostgreSQL
select pg1c.create_table('Справочник.Товары', schema=>'public', table_name_pg=>'Goods');

-- Создаем все таблицы
call pg1c.create_table_all();

-- Получаем список всех созданных таблиц
select * from pg1c.table;